use crate::domain::auth::{AuthError, AuthToken, LoginCredentials};
use crate::domain::ports::auth_repository::AuthRepository;
use crate::use_cases::auth::AuthUseCase;
use actix_web::{web, HttpResponse, Responder};
use serde_json::json;
use std::sync::Arc;

pub struct AuthHandler<R: AuthRepository> {
    auth_use_case: Arc<AuthUseCase<R>>,
}

impl<R: AuthRepository> AuthHandler<R> {
    pub fn new(auth_use_case: Arc<AuthUseCase<R>>) -> Self {
        Self { auth_use_case }
    }

    pub async fn login(
        credentials: web::Json<LoginCredentials>,
        handler: web::Data<Self>,
    ) -> impl Responder {
        match handler.auth_use_case.login(credentials.into_inner()).await {
            Ok(token) => HttpResponse::Ok().json(token),
            Err(e) => HttpResponse::Unauthorized().json(e),
        }
    }
}
