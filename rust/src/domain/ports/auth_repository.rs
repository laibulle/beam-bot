use crate::domain::auth::{AuthError, AuthToken, User};
use async_trait::async_trait;

#[async_trait]
pub trait AuthRepository: Send + Sync {
    async fn find_user_by_email(&self, email: &str) -> Result<Option<User>, AuthError>;
    async fn verify_password(&self, user: &User, password: &str) -> Result<bool, AuthError>;
    async fn generate_token(&self, user: &User) -> Result<AuthToken, AuthError>;
    async fn validate_token(&self, token: &str) -> Result<User, AuthError>;
}
