module.exports = {
  parser: '@typescript-eslint/parser',
  parserOptions: {
    project: 'tsconfig.json',
    tsconfigRootDir: __dirname,
    sourceType: 'module',
  },
  plugins: ['@typescript-eslint/eslint-plugin', 'import', 'unused-imports'],
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:prettier/recommended',
  ],
  root: true,
  env: {
    node: true,
    jest: true,
  },
  ignorePatterns: ['.eslintrc.js'],
  rules: {
    '@typescript-eslint/interface-name-prefix': 'off',
    '@typescript-eslint/explicit-function-return-type': 'off',
    '@typescript-eslint/explicit-module-boundary-types': 'off',
    '@typescript-eslint/no-explicit-any': 'off',
    'import/order': [
      'error',
      {
        'newlines-between': 'always',
        pathGroups: [
          {
            pattern: '@/**',
            group: 'internal',
          },
        ],
        groups: [
          ['builtin', 'external'],
          'internal',
          'parent',
          'sibling',
          'index',
          'object',
          'type',
        ],
        alphabetize: {
          order: 'asc',
          caseInsensitive: true,
        },
      },
    ],
    'import/newline-after-import': ['error', { count: 1 }],
    'unused-imports/no-unused-imports': 'error',
    curly: ['error', 'all'],
    'padding-line-between-statements': [
      'error',
      // Blank line before return
      { blankLine: 'always', prev: '*', next: 'return' },
      // Blank line before if
      { blankLine: 'always', prev: '*', next: 'if' },
    ],
    'no-restricted-syntax': [
      'error',
      {
        selector: "UnaryExpression[operator='delete']",
        message: 'Use of the `delete` operator is prohibited.',
      },
    ],
    'default-case': 'error',
    'eqeqeq': ['error', 'smart']
  },
};
