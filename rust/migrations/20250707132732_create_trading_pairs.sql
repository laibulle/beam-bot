CREATE TABLE IF NOT EXISTS trading_pairs (
    symbol VARCHAR(20) NOT NULL,
    exchange VARCHAR(20) NOT NULL,
    base_asset VARCHAR(20) NOT NULL,
    quote_asset VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,
    is_margin_trading BOOLEAN NOT NULL DEFAULT false,
    is_spot_trading BOOLEAN NOT NULL DEFAULT false,
    sync_start_time BIGINT,
    sync_end_time BIGINT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (symbol, exchange)
);

CREATE INDEX IF NOT EXISTS idx_trading_pairs_base_asset ON trading_pairs(base_asset);
CREATE INDEX IF NOT EXISTS idx_trading_pairs_quote_asset ON trading_pairs(quote_asset);
CREATE INDEX IF NOT EXISTS idx_trading_pairs_status ON trading_pairs(status);
CREATE INDEX IF NOT EXISTS idx_trading_pairs_exchange ON trading_pairs(exchange); 