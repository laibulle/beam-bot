use crate::domain::auth::{AuthError, AuthToken, User};
use crate::domain::ports::auth_repository::AuthRepository;
use crate::infrastructure::config::jwt::JwtConfig;
use chrono::{Duration, Utc};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: i32,
    exp: i64,
}

pub struct JwtRepository {
    config: JwtConfig,
}

impl JwtRepository {
    pub fn new(config: JwtConfig) -> Self {
        Self { config }
    }
}

#[async_trait::async_trait]
impl AuthRepository for JwtRepository {
    async fn find_user_by_email(&self, _email: &str) -> Result<Option<User>, AuthError> {
        Err(AuthError {
            message: "Not implemented".to_string(),
        })
    }

    async fn verify_password(&self, _user: &User, _password: &str) -> Result<bool, AuthError> {
        Err(AuthError {
            message: "Not implemented".to_string(),
        })
    }

    async fn generate_token(&self, user: &User) -> Result<AuthToken, AuthError> {
        let expiration = Utc::now() + Duration::days(self.config.expiration_days);
        let claims = Claims {
            sub: user.id,
            exp: expiration.timestamp(),
        };

        let token = encode(
            &Header::default(),
            &claims,
            &EncodingKey::from_secret(self.config.secret.as_bytes()),
        )
        .map_err(|e| AuthError {
            message: format!("Failed to generate token: {}", e),
        })?;

        Ok(AuthToken {
            token,
            expires_at: expiration,
        })
    }

    async fn validate_token(&self, token: &str) -> Result<User, AuthError> {
        let token_data = decode::<Claims>(
            token,
            &DecodingKey::from_secret(self.config.secret.as_bytes()),
            &Validation::default(),
        )
        .map_err(|e| AuthError {
            message: format!("Invalid token: {}", e),
        })?;

        Ok(User {
            id: token_data.claims.sub,
            email: "".to_string(),         // We don't store username in token
            password_hash: "".to_string(), // We don't store password in token
        })
    }
}
