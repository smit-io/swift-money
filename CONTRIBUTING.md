# Contributing to MoneyKit

Thank you for your interest in contributing to MoneyKit! This document provides guidelines and instructions for contributing.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/swift-money.git`
3. Create a feature branch: `git checkout -b feature/my-new-feature`
4. Make your changes
5. Run tests: `swift test`
6. Commit your changes: `git commit -am 'Add some feature'`
7. Push to the branch: `git push origin feature/my-new-feature`
8. Create a Pull Request

## Development Setup

### Requirements

- Swift 5.9 or later
- Xcode 15.0+ (for iOS/macOS development)
- SwiftLint (optional, for code quality)

### Building

```bash
swift build
```

### Running Tests

```bash
swift test
```

### Code Coverage

```bash
swift test --enable-code-coverage
```

## Code Style

We follow standard Swift conventions:

- Use 4 spaces for indentation (no tabs)
- Maximum line length: 120 characters
- Use descriptive variable and function names
- Add documentation comments for public APIs
- Follow SwiftLint rules (see `.swiftlint.yml`)

### Documentation

All public APIs should have documentation comments:

```swift
/// Brief description of what this does.
///
/// More detailed explanation if needed.
///
/// - Parameters:
///   - param1: Description of param1
///   - param2: Description of param2
/// - Returns: Description of return value
/// - Throws: Description of errors that can be thrown
public func myFunction(param1: Int, param2: String) throws -> String {
    // Implementation
}
```

## Testing Guidelines

- Write tests for all new functionality
- Maintain or improve code coverage
- Use descriptive test names: `func testFeatureBehavior()`
- Test edge cases and error conditions
- Use Swift Testing framework

### Test Structure

```swift
import Testing
@testable import MoneyKit

@Suite("Feature Tests")
struct FeatureTests {
    @Test("Description of what is being tested")
    func testSomething() throws {
        // Arrange
        let input = ...

        // Act
        let result = ...

        // Assert
        #expect(result == expected)
    }
}
```

## Pull Request Process

1. **Update Documentation**: Ensure README and code comments are updated
2. **Add Tests**: All new code should have corresponding tests
3. **Run Tests**: Verify all tests pass locally
4. **Update CHANGELOG**: Add entry describing your changes
5. **Describe Changes**: Provide clear PR description

### PR Checklist

- [ ] Code follows Swift style guidelines
- [ ] Tests added for new functionality
- [ ] All tests pass (`swift test`)
- [ ] Documentation updated (README, comments)
- [ ] No SwiftLint warnings
- [ ] CHANGELOG updated

## What to Contribute

### Ideas for Contributions

- Bug fixes
- New currency support
- Performance improvements
- Documentation improvements
- Example code
- Test coverage improvements

### Priority Areas

- Multi-currency conversion support
- Additional rounding modes
- More currency metadata
- Performance optimizations
- Platform-specific features

## Reporting Issues

When reporting issues, please include:

1. **Description**: Clear description of the issue
2. **Steps to Reproduce**: Minimal code example
3. **Expected Behavior**: What you expected to happen
4. **Actual Behavior**: What actually happened
5. **Environment**: Swift version, platform, OS version

### Issue Template

```markdown
**Description**
A clear description of the issue.

**Steps to Reproduce**
\`\`\`swift
// Minimal code example
\`\`\`

**Expected Behavior**
What you expected to happen.

**Actual Behavior**
What actually happened.

**Environment**
- Swift version:
- Platform: iOS/macOS/Linux
- OS version:
```

## Code Review Process

1. Maintainers will review PRs within 1-2 weeks
2. Feedback will be provided as comments
3. Make requested changes and push to your branch
4. Once approved, PRs will be merged by maintainers

## Security Issues

Please report security vulnerabilities privately to the maintainers rather than opening public issues.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

Feel free to open a discussion or issue if you have questions about contributing!
