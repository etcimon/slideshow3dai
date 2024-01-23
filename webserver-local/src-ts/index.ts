import express from "express";

const app = express();
const port = 8080;

app.get("/walmart", async (req, res) => {
  // walmart
  // todo: 
  // - Define input parameters
  // - Save store & zip code combinations, reselect when zip code changes
  // - Parallelize with other grocery stores
  const walmart = require("./walmart")
  walmart(req, res)
});

app.get("/maxi", async (req, res) => {
  // walmart
  // todo: 
  // - Define input parameters
  // - Save store & zip code combinations, reselect when zip code changes
  // - Parallelize with other grocery stores
  const maxi = require("./maxi")
  maxi(req, res)
});

app.listen(port, () => {
  console.log(`Listening on port ${port}...`);
});
