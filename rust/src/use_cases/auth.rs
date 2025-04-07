use crate::domain::auth::{AuthError, AuthToken, LoginCredentials, User};
use crate::domain::ports::auth_repository::AuthRepository;

pub struct AuthUseCase<R: AuthRepository> {
    repository: R,
}

impl<R: AuthRepository> AuthUseCase<R> {
    pub fn new(repository: R) -> Self {
        Self { repository }
    }

    pub async fn login(&self, credentials: LoginCredentials) -> Result<AuthToken, AuthError> {
        let user = self
            .repository
            .find_user_by_email(&credentials.email)
            .await?
            .ok_or_else(|| AuthError {
                message: "Invalid email or password".to_string(),
            })?;

        let is_valid = self
            .repository
            .verify_password(&user, &credentials.password)
            .await?;

        if !is_valid {
            return Err(AuthError {
                message: "Invalid email or password".to_string(),
            });
        }

        self.repository.generate_token(&user).await
    }

    pub async fn validate_token(&self, token: &str) -> Result<User, AuthError> {
        self.repository.validate_token(token).await
    }
}
