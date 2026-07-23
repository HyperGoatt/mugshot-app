-- Enable pg_net extension for async HTTP requests
-- This is needed for the push notification trigger to work efficiently

CREATE EXTENSION IF NOT EXISTS pg_net;;
