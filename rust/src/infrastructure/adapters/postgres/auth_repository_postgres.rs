use crate::domain::auth::{AuthError, AuthToken, User};
use crate::domain::ports::auth_repository::AuthRepository;

use bcrypt::verify;
use sqlx::PgPool;

pub struct PostgresAuthRepository {
    pool: PgPool,
}

impl PostgresAuthRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait::async_trait]
impl AuthRepository for PostgresAuthRepository {
    async fn find_user_by_email(&self, email: &str) -> Result<Option<User>, AuthError> {
        let user = sqlx::query_as!(
            User,
            r#"
            SELECT id, email, password_hash
            FROM users
            WHERE email = $1
            "#,
            email
        )
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AuthError {
            message: format!("Database error: {}", e),
        })?;

        Ok(user)
    }

    async fn verify_password(&self, user: &User, password: &str) -> Result<bool, AuthError> {
        verify(password, &user.password_hash).map_err(|e| AuthError {
            message: format!("Password verification error: {}", e),
        })
    }

    async fn generate_token(&self, _user: &User) -> Result<AuthToken, AuthError> {
        Err(AuthError {
            message: "Token generation not implemented in Postgres repository".to_string(),
        })
    }

    async fn validate_token(&self, _token: &str) -> Result<User, AuthError> {
        Err(AuthError {
            message: "Token validation not implemented in Postgres repository".to_string(),
        })
    }
}
