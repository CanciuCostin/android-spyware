const { environment } = require('@rails/webpacker')
const webpack = require("webpack")

environment.plugins.append("Provide", new webpack.ProvidePlugin({
    $: 'jquery',
    jQuery: 'jquery',
    Popper: ['popper.js', 'default']
}))

// ── Code Splitting ──────────────────────────────────────────────────
// Separate vendor libraries into their own chunk for better caching.
environment.splitChunks((config) => {
  return Object.assign({}, config, {
    optimization: {
      splitChunks: {
        chunks: 'all',
        maxInitialRequests: Infinity,
        minSize: 30000,
        cacheGroups: {
          vendor: {
            test: /[\\/]node_modules[\\/]/,
            name: 'vendor',
            chunks: 'all',
            priority: 10
          },
          chartjs: {
            test: /[\\/]node_modules[\\/](chart\.js|chartjs-adapter-date-fns)[\\/]/,
            name: 'chartjs',
            chunks: 'all',
            priority: 20
          },
          xterm: {
            test: /[\\/]node_modules[\\/]xterm[\\/]/,
            name: 'xterm',
            chunks: 'all',
            priority: 20
          }
        }
      }
    }
  })
})

module.exports = environment
