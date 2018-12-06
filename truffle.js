module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545, // ganache default port
      network_id: "*"
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  license: "MIT"
};

