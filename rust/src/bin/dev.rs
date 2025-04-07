use log::info;
use rustbot::infrastructure::config::config::Config;

#[tokio::main]
async fn main() {
    // Load environment variables from .env file
    if let Err(e) = dotenv::dotenv() {
        info!("Failed to load .env file: {:?}", e);
    }

    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    let _config = Config::new();
}
