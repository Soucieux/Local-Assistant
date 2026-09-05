"""A2A v1.0 wire-contract tests."""

from __future__ import annotations

import unittest

from local_assistant_connector import constants
from local_assistant_connector.a2a import (
    parse_send_message_response,
    send_message_request,
    validate_agent_card,
)
from local_assistant_connector.models import ConnectorError


class A2ATests(unittest.TestCase):
    """Verify discovery, request identity, and bounded response parsing."""

    def test_builds_a2a_v1_send_message_with_exact_text(self) -> None:
        """The request carries the exact text under a stable message identity."""
        document = send_message_request("message-id", "context-id", "Exact text")

        self.assertEqual(document[constants.FIELD_METHOD], "SendMessage")
        message = document[constants.FIELD_PARAMS][constants.FIELD_MESSAGE]
        self.assertEqual(message[constants.FIELD_MESSAGE_ID], "message-id")
        self.assertEqual(message[constants.FIELD_CONTEXT_ID], "context-id")
        self.assertEqual(message[constants.FIELD_ROLE], "ROLE_USER")
        self.assertEqual(message[constants.FIELD_PARTS][0][constants.FIELD_TEXT], "Exact text")

    def test_accepts_only_the_loopback_jsonrpc_agent_interface(self) -> None:
        """A public A2A interface never satisfies Agent Card verification."""
        validate_agent_card(
            {
                "name": "OpenClaw",
                "version": "1.0.0",
                "supportedInterfaces": [
                    {
                        "url": "http://127.0.0.1:23116/local-assistant/v1/a2a-agent",
                        "protocolBinding": "JSONRPC",
                        "protocolVersion": "1.0",
                    }
                ],
            }
        )

        with self.assertRaisesRegex(
            ConnectorError,
            constants.ERROR_A2A_CARD_VERIFICATION,
        ):
            validate_agent_card(
                {
                    "name": "OpenClaw",
                    "version": "1.0.0",
                    "supportedInterfaces": [
                        {
                            "url": "https://public.example/a2a",
                            "protocolBinding": "JSONRPC",
                            "protocolVersion": "1.0",
                        }
                    ],
                }
            )

    def test_maps_an_input_required_task_to_the_connector_status(self) -> None:
        """A follow-up question becomes the typed input-required status."""
        answer, status = parse_send_message_response(
            {
                "jsonrpc": "2.0",
                "id": "message-id",
                "result": {
                    "task": {
                        "id": "server-task",
                        "contextId": "context-id",
                        "status": {
                            "state": "TASK_STATE_INPUT_REQUIRED",
                            "message": {
                                "messageId": "reply-id",
                                "contextId": "context-id",
                                "role": "ROLE_AGENT",
                                "parts": [{"text": "Which date?"}],
                            },
                        },
                    }
                },
            },
            "message-id",
            "context-id",
        )

        self.assertEqual(answer, "Which date?")
        self.assertEqual(status, constants.STATUS_INPUT_REQUIRED)


if __name__ == "__main__":
    unittest.main()
