use crate::domain::ports::binance_adapter::Kline;
use std::fmt;
use tokio_postgres::Error;

#[derive(Debug)]
pub enum KlinesRepositoryError {
    DatabaseError(String),
}

impl fmt::Display for KlinesRepositoryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            KlinesRepositoryError::DatabaseError(msg) => write!(f, "Database error: {}", msg),
        }
    }
}

impl From<Error> for KlinesRepositoryError {
    fn from(error: Error) -> Self {
        KlinesRepositoryError::DatabaseError(error.to_string())
    }
}

pub trait KlinesRepository {
    fn save_klines(
        &self,
        symbol: &str,
        interval: &str,
        klines: &[Kline],
    ) -> impl std::future::Future<Output = Result<(), KlinesRepositoryError>> + Send;
}
