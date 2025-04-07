use crate::domain::auth::AuthError;
use crate::domain::ports::auth_repository::AuthRepository;
use crate::use_cases::auth::AuthUseCase;
use actix_web::{
    dev::{Service, ServiceRequest, ServiceResponse},
    error::ErrorUnauthorized,
    web::Data,
    Error, HttpMessage,
};
use futures::future::{ready, Ready};
use std::sync::Arc;

pub fn auth_middleware<R: AuthRepository + 'static>(
    auth_use_case: Arc<AuthUseCase<R>>,
) -> impl Fn(ServiceRequest, &dyn Service<ServiceRequest>) -> Ready<Result<ServiceResponse, Error>>
{
    move |req, srv| {
        let auth_header = req
            .headers()
            .get("Authorization")
            .and_then(|header| header.to_str().ok())
            .and_then(|header| header.strip_prefix("Bearer "));

        let token = match auth_header {
            Some(token) => token.to_string(),
            None => {
                return ready(Err(ErrorUnauthorized(AuthError {
                    message: "Missing authorization token".to_string(),
                })));
            }
        };

        let auth_use_case = auth_use_case.clone();
        let fut = srv.call(req);

        ready(
            async move {
                match auth_use_case.validate_token(&token).await {
                    Ok(_user) => {
                        // You can store the user in the request extensions if needed
                        // req.extensions_mut().insert(user);
                        fut.await
                    }
                    Err(e) => Err(ErrorUnauthorized(e)),
                }
            }
            .await,
        )
    }
}
