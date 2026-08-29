"""Constants for connector configuration, contracts, and storage."""

from __future__ import annotations

APPLICATION_DIRECTORY_NAME = "LocalAssistantConnector"
USER_LIBRARY_DIRECTORY_NAME = "Library"
APPLICATION_SUPPORT_DIRECTORY_NAME = "Application Support"
CONFIG_FILE_NAME = "config.json"
CHECKPOINT_FILE_NAME = "checkpoints.sqlite3"
STATUS_FILE_NAME = "status.json"
SCHEDULE_FILE_NAME = "schedule.json"
SCHEDULED_SNAPSHOT_FILE_NAME = "scheduled-reminder-snapshot.json"
REQUESTS_DIRECTORY_NAME = "Requests"
PROCESSING_DIRECTORY_NAME = "Processing"
RESPONSES_DIRECTORY_NAME = "Responses"
JSON_SUFFIX = ".json"
TEMPORARY_SUFFIX = ".tmp"
OWNER_DIRECTORY_MODE = 0o700
OWNER_FILE_MODE = 0o600

SCHEMA_VERSION = 1
RUNTIME_CONTRACT_VERSION = 3
REMINDER_SKILL = "cloudbase-reminders"
AGENT_SKILL = "openclaw-agent"
REMINDER_ROUTE_PATH = "/local-assistant/v1/a2a"
A2A_AGENT_CARD_ROUTE_PATH = "/.well-known/agent-card.json"
A2A_AGENT_ROUTE_PATH = "/local-assistant/v1/a2a-agent"
A2A_PROTOCOL_VERSION = "1.0"
A2A_AGENT_NAME = "OpenClaw"
A2A_PROTOCOL_BINDING = "JSONRPC"
A2A_JSONRPC_VERSION = "2.0"
A2A_METHOD_SEND_MESSAGE = "SendMessage"
A2A_ROLE_USER = "ROLE_USER"
A2A_ROLE_AGENT = "ROLE_AGENT"
A2A_TASK_STATE_COMPLETED = "TASK_STATE_COMPLETED"
A2A_TASK_STATE_INPUT_REQUIRED = "TASK_STATE_INPUT_REQUIRED"
CALENDAR_POLICY_NEVER = "never"
CALENDAR_POLICY_OPENCLAW_DEFAULT = "openclaw-default"
STATUS_COMPLETED = "completed"
STATUS_FAILED = "failed"
STATUS_INPUT_REQUIRED = "input-required"
OPERATION_LIST = "list"
OPERATION_CHAT = "chat"
OPENCLAW_INVOCATION_PATTERN = r"(?iu)(?<!\w)open(?:\s+)?claw(?!\w)"
AUTHORIZATION_EXPLICIT_OPENCLAW = "explicit-openclaw"
AUTHORIZATION_CONFIRMED_REMINDER_MUTATION = "confirmed-reminder-mutation"
INVALID_REQUEST_THREAD_ID = "invalid-request"

FIELD_SCHEMA_VERSION = "schemaVersion"
FIELD_TASK_ID = "taskId"
FIELD_CONTEXT_ID = "contextId"
FIELD_SKILL = "skill"
FIELD_OPERATION = "operation"
FIELD_IDEMPOTENCY_KEY = "idempotencyKey"
FIELD_CALENDAR_POLICY = "calendarPolicy"
FIELD_CONFIRMED = "confirmed"
FIELD_AUTHORIZATION = "authorization"
FIELD_PAYLOAD = "payload"
FIELD_STATUS = "status"
FIELD_CALENDAR_CHANGED = "calendarChanged"
FIELD_ERROR = "error"
FIELD_KIND = "kind"
FIELD_MESSAGE = "message"
FIELD_RETRYABLE = "retryable"
FIELD_ROLE = "role"
FIELD_SUCCESS = "success"
FIELD_DATA = "data"
FIELD_NAME = "name"
FIELD_VERSION = "version"
FIELD_SUPPORTED_INTERFACES = "supportedInterfaces"
FIELD_URL = "url"
FIELD_PROTOCOL_BINDING = "protocolBinding"
FIELD_PROTOCOL_VERSION = "protocolVersion"
FIELD_JSONRPC = "jsonrpc"
FIELD_ID = "id"
FIELD_METHOD = "method"
FIELD_PARAMS = "params"
FIELD_RESULT = "result"
FIELD_TASK = "task"
FIELD_PARTS = "parts"
FIELD_TEXT = "text"
FIELD_MEDIA_TYPE = "mediaType"
FIELD_MESSAGE_ID = "messageId"
FIELD_STATE = "state"

AGENT_PAYLOAD_FIELDS = frozenset({FIELD_MESSAGE})
REQUEST_REQUIRED_FIELDS = frozenset(
    {
        FIELD_SCHEMA_VERSION,
        FIELD_TASK_ID,
        FIELD_SKILL,
        FIELD_OPERATION,
        FIELD_IDEMPOTENCY_KEY,
        FIELD_CALENDAR_POLICY,
        FIELD_CONFIRMED,
        FIELD_PAYLOAD,
    }
)
REQUEST_OPTIONAL_FIELDS = frozenset({FIELD_CONTEXT_ID, FIELD_AUTHORIZATION})

CONFIG_SSH_HOST = "sshHost"
CONFIG_SSH_PORT = "sshPort"
CONFIG_SSH_USER = "sshUser"
CONFIG_SPOOL_DIRECTORY = "spoolDirectory"
CONFIG_REQUEST_TIMEOUT_SECONDS = "requestTimeoutSeconds"
CONFIG_REQUIRED_FIELDS = frozenset(
    {CONFIG_SSH_HOST, CONFIG_SSH_PORT, CONFIG_SSH_USER, CONFIG_SPOOL_DIRECTORY}
)
CONFIG_OPTIONAL_FIELDS = frozenset({CONFIG_REQUEST_TIMEOUT_SECONDS})
DEFAULT_REQUEST_TIMEOUT_SECONDS = 20.0
MINIMUM_REQUEST_TIMEOUT_SECONDS = 1.0
MAXIMUM_REQUEST_TIMEOUT_SECONDS = 120.0
DEFAULT_SSH_PORT = 22
SSH_EXECUTABLE = "/usr/bin/ssh"
SSH_DIRECTORY_NAME = "ssh"
SSH_PRIVATE_KEY_NAME = "id_ed25519"
SSH_PUBLIC_KEY_NAME = "id_ed25519.pub"
SSH_KNOWN_HOSTS_NAME = "known_hosts"
SSH_HOST_KEY_ALIAS = "local-assistant-openclaw-server"
SSH_KEY_TYPE = "ssh-ed25519"
SSH_HOST_KEY_MINIMUM_BYTES = 32
SSH_HOST_KEY_FIELD_COUNT = 3
SSH_HOST_MAXIMUM_LENGTH = 253
SSH_PORT_MINIMUM = 1
SSH_PORT_MAXIMUM = 65_535
SSH_REMOTE_GATEWAY_HOST = "127.0.0.1"
SSH_REMOTE_GATEWAY_PORT = 23_116
SSH_LOOPBACK_HOST = "127.0.0.1"
LOOPBACK_URL_SCHEME = "http"
SSH_CONNECT_TIMEOUT_SECONDS = 12
SSH_READY_POLL_SECONDS = 0.1
SSH_SHUTDOWN_TIMEOUT_SECONDS = 3

KEYCHAIN_SERVICE = "com.soucieux.LocalAssistant.OpenClawConnector"
KEYCHAIN_REMINDER_ACCOUNT = "reminder-snapshot-token"
KEYCHAIN_AGENT_ACCOUNT = "openclaw-agent-token"
KEYCHAIN_SECURITY_EXECUTABLE = "/usr/bin/security"
KEYCHAIN_FIND_GENERIC_PASSWORD = "find-generic-password"
KEYCHAIN_SERVICE_OPTION = "-s"
KEYCHAIN_ACCOUNT_OPTION = "-a"
KEYCHAIN_METADATA_TIMEOUT_SECONDS = 5

HEADER_AUTHORIZATION = "Authorization"
HEADER_CONTENT_TYPE = "Content-Type"
HEADER_ACCEPT = "Accept"
CONTENT_TYPE_JSON = "application/json"
CONTENT_TYPE_TEXT_PLAIN = "text/plain"
CONTENT_TYPE_A2A_JSON = CONTENT_TYPE_JSON
BEARER_PREFIX = "Bearer "
HTTP_GET = "GET"
HTTP_POST = "POST"
MAX_REQUEST_BYTES = 65_536
MAX_RESPONSE_BYTES = 2_097_152
MAX_AGENT_MESSAGE_CHARACTERS = 8_000
MAX_AGENT_ANSWER_CHARACTERS = 8_000
AGENT_ANSWER_SEPARATOR = "\n\n"
MAX_RETRY_ATTEMPTS = 3
RETRY_BASE_SECONDS = 0.5
AUTHENTICATION_HTTP_STATUS = frozenset({401, 403})
RETRYABLE_HTTP_STATUS = frozenset({408, 425, 429, 500, 502, 503, 504})

ERROR_INVALID_CONFIG = "connector configuration is invalid"
ERROR_CONFIG_MISSING = "connector configuration does not exist"
ERROR_SSH_HOST = "the SSH server address is invalid"
ERROR_SSH_PORT = "the SSH server port is invalid"
ERROR_SSH_USER = "the restricted SSH account is invalid"
ERROR_SSH_IDENTITY = "the dedicated SSH identity is missing or unsafe"
ERROR_SSH_HOST_KEY = "the OpenClaw server SSH host key is invalid"
ERROR_TOKEN_MISSING = "the required Keychain token is not configured"
ERROR_INVALID_REQUEST = "connector request is invalid"
ERROR_TOO_LARGE = "connector request is too large"
ERROR_UNSUPPORTED_SKILL = "connector skill is unsupported"
ERROR_REMINDER_PAYLOAD = "only an unconfirmed complete reminder snapshot is allowed"
ERROR_AGENT_PAYLOAD = "agent payload is invalid"
ERROR_AGENT_MESSAGE = "agent message is invalid"
ERROR_OPENCLAW_REQUIRED = "explicit agent requests must name OpenClaw"
ERROR_REMOTE = "OpenClaw request failed"
ERROR_AUTHENTICATION = "OpenClaw rejected the configured token"
ERROR_UNREACHABLE = "the restricted SSH tunnel could not reach OpenClaw"
ERROR_SSH_HOST_KEY_MISMATCH = "the pinned SSH host key does not match the server"
ERROR_SSH_PUBLIC_KEY_REJECTED = "the server rejected the Connector public key"
ERROR_SSH_HOST_UNRESOLVED = "the SSH server address could not be resolved"
ERROR_SSH_CONNECTION_REFUSED = "the SSH server refused the connection"
ERROR_SSH_CONNECTION_TIMEOUT = "the SSH server connection timed out"
ERROR_SSH_NETWORK_UNREACHABLE = "the SSH server is unreachable from this Mac"
SSH_DIAGNOSTIC_ERRORS = frozenset(
    {
        ERROR_UNREACHABLE,
        ERROR_SSH_HOST_KEY_MISMATCH,
        ERROR_SSH_PUBLIC_KEY_REJECTED,
        ERROR_SSH_HOST_UNRESOLVED,
        ERROR_SSH_CONNECTION_REFUSED,
        ERROR_SSH_CONNECTION_TIMEOUT,
        ERROR_SSH_NETWORK_UNREACHABLE,
    }
)
ERROR_REMOTE_RESPONSE = "OpenClaw returned an invalid response"
ERROR_REDIRECT = "OpenClaw redirected outside the configured origin"
ERROR_FILE_BOUNDARY = "connector spool file is unsafe"
ERROR_INTERNAL = "connector could not complete the request"
ERROR_VERIFICATION = "OpenClaw did not return a complete reminder snapshot"
ERROR_A2A_CARD_VERIFICATION = "OpenClaw did not return a compatible A2A Agent Card"
ERROR_KIND_INVALID_REQUEST = "invalid_request"
ERROR_KIND_OPERATIONAL = "operational"
ERROR_KIND_NOT_CONFIGURED = "not_configured"

STATUS_KEY_RUNNING = "running"
STATUS_KEY_LAST_SEEN_AT = "lastSeenAt"
STATUS_KEY_LAST_SUCCESS_AT = "lastSuccessAt"
STATUS_KEY_LAST_REMINDER_SUCCESS_AT = "lastReminderSuccessAt"
STATUS_KEY_LAST_ERROR = "lastError"
STATUS_KEY_PID = "pid"
STATUS_KEY_SCHEMA_VERSION = FIELD_SCHEMA_VERSION
STATUS_KEY_RUNTIME_CONTRACT_VERSION = "runtimeContractVersion"
SCHEDULE_KEY_ENABLED = "enabled"
SCHEDULE_KEY_INTERVAL_MINUTES = "intervalMinutes"
ALLOWED_SCHEDULE_INTERVAL_MINUTES = frozenset({120, 240, 480})
ISO8601_UTC_FORMAT = "%Y-%m-%dT%H:%M:%SZ"

CLI_CONFIGURE = "configure"
CLI_SETUP_STDIN = "setup-stdin"
CLI_RECONFIGURE_STDIN = "reconfigure-stdin"
CLI_SET_REMINDER_TOKEN = "set-reminder-token"
CLI_SET_AGENT_TOKEN = "set-agent-token"
CLI_SET_SSH_HOST_KEY = "set-ssh-host-key"
CLI_ONCE = "once"
CLI_STATUS = "status"
CLI_VERIFY = "verify"
CLI_SETUP_STATE = "setup-state"
CLI_FORGET = "forget"
CLI_DESCRIPTION = "Run the opt-in Local Assistant OpenClaw connector."
CLI_ARGUMENT_COMMAND = "command"
CLI_ARGUMENT_SSH_HOST = "--ssh-host"
CLI_ARGUMENT_SSH_PORT = "--ssh-port"
CLI_ARGUMENT_SSH_USER = "--ssh-user"
CLI_ARGUMENT_SPOOL = "--spool"
CLI_ARGUMENT_REQUEST_TIMEOUT = "--request-timeout"
CLI_PROMPT_REMINDER_TOKEN = "Dedicated OpenClaw reminder snapshot token: "
CLI_PROMPT_AGENT_TOKEN = "OpenClaw Gateway agent token: "
CLI_PROMPT_SSH_HOST_KEY = "Complete OpenClaw server ssh-ed25519 host-key line: "
CLI_CONFIGURED = "Connector configuration saved without credentials."
CLI_SETUP_SAVED = "Connector configuration and Keychain credentials saved."
CLI_TOKEN_SAVED = "Token saved in macOS Keychain."
CLI_SSH_HOST_KEY_SAVED = "Pinned SSH host key saved."
CLI_VERIFIED = "Connector connection verified."
CLI_FORGOTTEN = "Connector data removed."
CLI_EXIT_FAILURE = 1
CLI_EXIT_AUTHENTICATION = 10
CLI_EXIT_UNREACHABLE = 11
CLI_EXIT_SNAPSHOT = 12
CLI_EXIT_A2A = 13
SETUP_REMINDER_TOKEN = "reminderToken"
SETUP_AGENT_TOKEN = "agentToken"
SETUP_SSH_HOST_KEY = "sshHostKey"
SETUP_REQUIRED_FIELDS = frozenset(
    {
        CONFIG_SSH_HOST,
        CONFIG_SSH_PORT,
        CONFIG_SSH_USER,
        CONFIG_SPOOL_DIRECTORY,
        SETUP_SSH_HOST_KEY,
        SETUP_REMINDER_TOKEN,
        SETUP_AGENT_TOKEN,
    }
)
RECONFIGURE_REQUIRED_FIELDS = frozenset(
    {
        CONFIG_SSH_HOST,
        CONFIG_SSH_PORT,
        CONFIG_SSH_USER,
        CONFIG_SPOOL_DIRECTORY,
        SETUP_SSH_HOST_KEY,
    }
)
MAX_SETUP_STDIN_BYTES = 16_384
