import { createServer } from "node:http"
import handler from "serve-handler"

const port = Number(process.env.PORT) || 8080
const host = process.env.HOST || "0.0.0.0"

const server = createServer((req, res) =>
  handler(req, res, {
    public: "public",
    cleanUrls: true,
  }),
)

server.listen(port, host, () => {
  console.log(`Serving public/ at http://${host}:${port}`)
})
