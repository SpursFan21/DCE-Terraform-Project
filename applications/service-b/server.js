const http = require("http");

const service = "service-b";
const version = "v2";
const port = 8080;

const server = http.createServer((req, res) => {
  res.setHeader("Content-Type", "application/json");

  if (req.url === "/health") {
    res.writeHead(200);
    return res.end(JSON.stringify({
      status: "healthy",
      service
    }));
  }

  if (req.url === "/") {
    res.writeHead(200);
    return res.end(JSON.stringify({
      message: "DCE04 Service B is running!",
      service,
      version
    }));
  }

  res.writeHead(404);
  res.end(JSON.stringify({ error: "Not Found" }));
});

server.listen(port, "0.0.0.0", () => {
  console.log(`${service} listening on port ${port}`);
});