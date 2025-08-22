module.exports = {
  env: {
    browser: false,
    es2021: true,
    node: true,
    jest: true
  },
  extends: [
    'standard'
  ],
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module'
  },
  rules: {
    // Enforce semicolons for consistency
    'semi': ['error', 'always'],
    
    // Allow console.log for Lambda logging
    'no-console': 'off',
    
    // Enforce consistent spacing
    'space-before-function-paren': ['error', 'never'],
    
    // Allow trailing commas for cleaner diffs
    'comma-dangle': ['error', 'always-multiline'],
    
    // Enforce consistent quotes
    'quotes': ['error', 'single'],
    
    // Enforce consistent indentation
    'indent': ['error', 2],
    
    // Enforce consistent line endings
    'eol-last': ['error', 'always'],
    
    // Disallow unused variables except for function arguments
    'no-unused-vars': ['error', { 'argsIgnorePattern': '^_' }],
    
    // Enforce consistent object property spacing
    'key-spacing': ['error', { 'beforeColon': false, 'afterColon': true }],
    
    // Enforce consistent array bracket spacing
    'array-bracket-spacing': ['error', 'never'],
    
    // Enforce consistent object brace spacing
    'object-curly-spacing': ['error', 'always']
  },
  overrides: [
    {
      files: ['**/*.test.js'],
      env: {
        jest: true
      },
      rules: {
        // Allow longer lines in tests for readability
        'max-len': 'off'
      }
    }
  ]
};