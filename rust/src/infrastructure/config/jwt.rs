use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct JwtConfig {
    pub secret: String,
    pub expiration_days: i64,
}

impl JwtConfig {
    pub fn new(secret: String, expiration_days: i64) -> Self {
        Self {
            secret,
            expiration_days,
        }
    }
}
