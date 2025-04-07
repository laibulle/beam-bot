use crate::domain::auth::{AuthError, AuthToken, User};
use crate::domain::ports::auth_repository::AuthRepository;
use crate::infrastructure::adapters::jwt_repository::JwtRepository;
use crate::infrastructure::adapters::postgres::auth_repository_postgres::PostgresAuthRepository;

pub struct CompositeAuthRepository {
    postgres_repo: PostgresAuthRepository,
    jwt_repo: JwtRepository,
}

impl CompositeAuthRepository {
    pub fn new(postgres_repo: PostgresAuthRepository, jwt_repo: JwtRepository) -> Self {
        Self {
            postgres_repo,
            jwt_repo,
        }
    }
}

#[async_trait::async_trait]
impl AuthRepository for CompositeAuthRepository {
    async fn find_user_by_email(&self, email: &str) -> Result<Option<User>, AuthError> {
        self.postgres_repo.find_user_by_email(email).await
    }

    async fn verify_password(&self, user: &User, password: &str) -> Result<bool, AuthError> {
        self.postgres_repo.verify_password(user, password).await
    }

    async fn generate_token(&self, user: &User) -> Result<AuthToken, AuthError> {
        self.jwt_repo.generate_token(user).await
    }

    async fn validate_token(&self, token: &str) -> Result<User, AuthError> {
        self.jwt_repo.validate_token(token).await
    }
}
