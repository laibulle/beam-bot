use rustbot::infrastructure::config::postgres_config::PostgresConfig;

#[test]
fn test_default_config() {
    let config = PostgresConfig::default();
    assert_eq!(config.host, "localhost");
    assert_eq!(config.port, 5432);
    assert_eq!(config.user, "postgres");
    assert_eq!(config.password, "postgres");
    assert_eq!(config.dbname, "rustbot");
}

#[test]
fn test_parse_valid_url() {
    let url = "postgres://user:pass@localhost:5432/mydb";
    let config = PostgresConfig::from_url(url).unwrap();

    assert_eq!(config.host, "localhost");
    assert_eq!(config.port, 5432);
    assert_eq!(config.user, "user");
    assert_eq!(config.password, "pass");
    assert_eq!(config.dbname, "mydb");
}

#[test]
fn test_parse_url_without_port() {
    let url = "postgres://user:pass@localhost/mydb";
    let config = PostgresConfig::from_url(url).unwrap();

    assert_eq!(config.port, 5432); // Should use default port
}

#[test]
fn test_parse_url_without_password() {
    let url = "postgres://user@localhost/mydb";
    let config = PostgresConfig::from_url(url).unwrap();

    assert_eq!(config.password, ""); // Empty password
}

#[test]
fn test_invalid_scheme() {
    let url = "http://user:pass@localhost/mydb";
    let result = PostgresConfig::from_url(url);
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("Invalid scheme"));
}

#[test]
fn test_connection_string() {
    let config = PostgresConfig {
        host: "localhost".to_string(),
        port: 5432,
        user: "user".to_string(),
        password: "pass".to_string(),
        dbname: "mydb".to_string(),
    };

    assert_eq!(
        config.connection_string(),
        "postgres://user:pass@localhost:5432/mydb"
    );
}
