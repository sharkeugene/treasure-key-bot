const path = require("path");

module.exports = {
  resolve: {
    extensions: [".tsx", ".ts", ".js"],
  },
  devtool: "source-map",
  entry: "./electron/main.ts",
  target: "electron-main",
  resolve: {
    // configuration options
    extensions: ['.js', '.ts', '.tsx', '.json'],
  },
  module: {
    rules: [
      {
        test: /\.(js|ts|tsx)$/,
        exclude: path.resolve(__dirname, 'node_modules'),
        use: {
          loader: "babel-loader",
        },
      },
    ],
  },
  node: {
    __dirname: false,
  },
  output: {
    path: path.resolve(__dirname, "dist"),
    filename: "[name].js",
  },
};
