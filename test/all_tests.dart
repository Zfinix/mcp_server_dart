/// Comprehensive test suite for the MCP Dart framework
///
/// This file runs all tests in the project and provides a single entry point
/// for running the complete test suite.
///
/// Run with: dart test test/all_tests.dart

import 'annotations_test.dart' as annotations_tests;
import 'mcp_server_test.dart' as server_tests;
import 'production_mcp_test.dart' as production_tests;
import 'protocol_types_test.dart' as protocol_tests;

void main() {
  // Run all test suites
  annotations_tests.main();
  server_tests.main();
  protocol_tests.main();
  production_tests.main();
}
