module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-enum': [
      2,
      'always',
      [
        'frontend',
        'api',
        'middleware',
        'cache',
        'admin',
        'qa',
        'backend',
        'observability',
        'frontend/ios',
        'design',
        'review',
        'security',
        'repo',
        'harness',
        'docs',
        'ci',
        'deps',
      ],
    ],
    'header-max-length': [2, 'always', 100],
  },
};
