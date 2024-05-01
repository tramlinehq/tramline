const defaultTheme = require('tailwindcss/defaultTheme')
const colors = require('tailwindcss/colors')

module.exports = {
  darkMode: 'class',
  content: [
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*',
    './app/components/v2/**/*',
    './app/components/**/*',
  ],
  safelist: [
    {
      pattern: /(bg|text)-(.*)-(.*)/,
    },
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          "50": "#eff6ff",
          "100": "#dbeafe",
          "200": "#bfdbfe",
          "300": "#93c5fd",
          "400": "#60a5fa",
          "500": "#3b82f6",
          "600": "#2563eb",
          "700": "#1d4ed8",
          "800": "#1e40af",
          "900": "#1e3a8a",
          "950": "#172554"
        },
        secondary: {
          "50": "rgb(147 157 184/var(--tw-text-opacity))",
          DEFAULT: "rgb(100 110 135/var(--tw-text-opacity))"
        },
        main: {
          ...colors.gray,
          DEFAULT: "#1f2937"
        },
        reldexExcellent: {
          ...colors.emerald
        },
        reldexAcceptable: {
          ...colors.blue
        },
        reldexMediocre: {
          ...colors.red
        },
        backgroundLight: {
          "50": "hsl(0, 0%, 97.8%)",
          "100": "hsl(0, 0%, 96.5%)",
          DEFAULT: "rgb(251 252 252/1)"
        },
        backgroundDark: "rgb(31 41 55/1)",
      },
      boxShadow: {
        DEFAULT: '0 1px 3px 0 rgba(0, 0, 0, 0.01), 0 1px 2px -1px rgba(0, 0, 0, 0.1)',
        md: '0 4px 6px -1px rgba(0, 0, 0, 0.08), 0 2px 4px -1px rgba(0, 0, 0, 0.02)',
        lg: '0 10px 15px -3px rgba(0, 0, 0, 0.08), 0 4px 6px -2px rgba(0, 0, 0, 0.01)',
        xl: '0 20px 25px -5px rgba(0, 0, 0, 0.08), 0 10px 10px -5px rgba(0, 0, 0, 0.01)',
      },
      outline: {
        blue: '2px solid rgba(0, 112, 244, 0.5)',
      },
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
      fontSize: {
        xs: ['0.75rem', {lineHeight: '1.5'}],
        sm: ['0.875rem', {lineHeight: '1.5715'}],
        base: ['1rem', {lineHeight: '1.5', letterSpacing: '-0.01em'}],
        lg: ['1.125rem', {lineHeight: '1.5', letterSpacing: '-0.01em'}],
        xl: ['1.25rem', {lineHeight: '1.5', letterSpacing: '-0.01em'}],
        '2xl': ['1.5rem', {lineHeight: '1.33', letterSpacing: '-0.01em'}],
        '3xl': ['1.88rem', {lineHeight: '1.33', letterSpacing: '-0.01em'}],
        '4xl': ['2.25rem', {lineHeight: '1.25', letterSpacing: '-0.02em'}],
        '5xl': ['3rem', {lineHeight: '1.25', letterSpacing: '-0.02em'}],
        '6xl': ['3.75rem', {lineHeight: '1.2', letterSpacing: '-0.02em'}],
      },
      screens: {
        xs: '480px',
      },
      borderWidth: {
        3: '3px',
      },
      minWidth: {
        36: '9rem',
        44: '11rem',
        56: '14rem',
        60: '15rem',
        72: '18rem',
        80: '20rem',
      },
      maxWidth: {
        '8xl': '88rem',
        '9xl': '96rem',
      },
      zIndex: {
        60: '60',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
  ]
}
