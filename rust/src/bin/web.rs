use actix::{Actor, ActorContext, AsyncContext, StreamHandler};
use actix_cors::Cors;
use actix_web::{web, App, Error, HttpRequest, HttpResponse, HttpServer};
use actix_web_actors::ws::{self, Message, ProtocolError, WebsocketContext};
use chrono;
use log::info;
use rmp_serde::Serializer;
//use rustbot::infrastructure::adapters::composite_auth_repository::CompositeAuthRepository;
//use rustbot::infrastructure::adapters::jwt_repository::JwtRepository;
//use rustbot::infrastructure::adapters::postgres::auth_repository_postgres::PostgresAuthRepository;
//use rustbot::infrastructure::api::auth_handler::AuthHandler;
//use rustbot::infrastructure::api::middleware::auth_middleware::AuthMiddleware;
use rustbot::infrastructure::config::config::Config;
//use rustbot::infrastructure::config::jwt::JwtConfig;
//use rustbot::use_cases::auth::AuthUseCase;
use serde::{Deserialize, Serialize};
//use sqlx::postgres::PgPoolOptions;
//use std::sync::Arc;
use std::time::{Duration, Instant};

#[derive(Serialize, Deserialize)]
struct ApiResponse {
    message: String,
}

#[derive(Serialize, Deserialize)]
struct WsMessage {
    message: String,
    timestamp: i64,
}

struct WsSession {
    hb: Instant,
}

impl Actor for WsSession {
    type Context = WebsocketContext<Self>;

    fn started(&mut self, ctx: &mut Self::Context) {
        self.hb(ctx);
    }
}

impl WsSession {
    fn hb(&self, ctx: &mut WebsocketContext<Self>) {
        ctx.run_interval(Duration::from_secs(5), |act, ctx| {
            if Instant::now().duration_since(act.hb) > Duration::from_secs(10) {
                ctx.stop();
                return;
            }
            ctx.ping(b"");
        });
    }
}

impl StreamHandler<Result<Message, ProtocolError>> for WsSession {
    fn handle(&mut self, msg: Result<Message, ProtocolError>, ctx: &mut Self::Context) {
        match msg {
            Ok(Message::Ping(msg)) => {
                self.hb = Instant::now();
                ctx.pong(&msg);
            }
            Ok(Message::Pong(_)) => {
                self.hb = Instant::now();
            }
            Ok(Message::Binary(bin)) => {
                if let Ok(msg) = rmp_serde::from_slice::<WsMessage>(&bin) {
                    let response = WsMessage {
                        message: format!("Echo: {}", msg.message),
                        timestamp: chrono::Utc::now().timestamp(),
                    };

                    let mut buf = Vec::new();
                    response.serialize(&mut Serializer::new(&mut buf)).unwrap();
                    ctx.binary(buf);
                }
            }
            Ok(Message::Close(reason)) => {
                ctx.close(reason);
                ctx.stop();
            }
            _ => ctx.stop(),
        }
    }
}

async fn ws_index(r: HttpRequest, stream: web::Payload) -> Result<HttpResponse, Error> {
    ws::start(WsSession { hb: Instant::now() }, &r, stream)
}

async fn hello() -> HttpResponse {
    let response = ApiResponse {
        message: String::from("Welcome to RustBot API!"),
    };
    HttpResponse::Ok().json(response)
}

#[actix_web::main]
async fn main() {
    // Load environment variables
    if let Err(e) = dotenv::dotenv().or_else(|_| dotenv::from_filename("../.env")) {
        info!("Failed to load .env file: {:?}", e);
    }

    // Initialize logging
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp(None)
        .format_level(true)
        .init();

    // Load configuration
    let _config = Config::new();
    // let jwt_config = JwtConfig::new(
    //     std::env::var("JWT_SECRET").expect("JWT_SECRET must be set"),
    //     7, // 7 days token expiration
    // );

    // Initialize database connection
    // let pool = PgPoolOptions::new()
    //     .max_connections(5)
    //     .connect(&config.postgres_config.connection_string())
    //     .await
    //     .expect("Failed to connect to database");

    // Initialize repositories
    //let postgres_repo = PostgresAuthRepository::new(pool.clone());
    //let jwt_repo = JwtRepository::new(jwt_config);
    //let auth_repo = CompositeAuthRepository::new(postgres_repo, jwt_repo);

    // Initialize use case
    //let auth_use_case = Arc::new(AuthUseCase::new(auth_repo));

    // Initialize handlers
    //let auth_handler = Arc::new(AuthHandler::new(auth_use_case.clone()));

    // Create Actix server
    let addr = "0.0.0.0:3001";
    info!("Server running on {}", addr);

    HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allow_any_method()
            .allow_any_header()
            .max_age(3600);

        App::new()
            .wrap(cors)
            //.app_data(web::Data::new(auth_handler.clone()))
            .service(web::resource("/ws/").to(ws_index))
            .service(web::resource("/").to(hello))
        // .service(
        //     web::scope("/auth")
        //         .service(
        //             web::resource("/login").to(AuthHandler::<CompositeAuthRepository>::login),
        //         )
        //         .wrap(AuthMiddleware::<CompositeAuthRepository>::new()),
        // )
    })
    .bind(addr)
    .expect("Failed to bind server")
    .run()
    .await
    .unwrap();
}
