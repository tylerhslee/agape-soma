# agape-app standard image — two targets from one build:
#   api    — your application server (embeds the agape-ts runtime in-process)
#   studio — Agape Studio (editor, orchestration graph, ledger, provider menu)
#
# Prerequisites in your repo:
#   vendor/agape-ts/   the Agape TypeScript runtime (rsync from the agape
#                      checkout, excluding node_modules/.git/conformance/test)
#   agape/             your Agape project: agape.toml + programs/*.ag
#   scripts/cloud-entrypoint.sh, scripts/studio-cloud.sh   (from this kit)
FROM node:24-slim AS base

WORKDIR /app

# App dependencies first for layer caching.
COPY package.json package-lock.json ./
RUN npm ci

# Vendored Agape runtime: its own runtime deps (provider SDKs), no dev deps —
# your app's tsx executes agape-ts sources in-process.
COPY vendor/agape-ts/package.json vendor/agape-ts/package-lock.json ./vendor/agape-ts/
RUN cd vendor/agape-ts && npm ci --omit=dev

# Copy source and build. Adapt the build command to your app.
COPY . .
RUN npm run build

ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=8080
ENV DATA_DIR=/data
ENV AGAPE_TS_HOME=/app/vendor/agape-ts
# The image ships the seed Agape project; in cloud both services point
# AGAPE_PROJECT_DIR at the persistent mount and the entrypoint seeds it.
ENV AGAPE_SEED_DIR=/app/agape

EXPOSE 8080

FROM base AS api
# Adapt to your app's start command.
CMD ["bash", "scripts/cloud-entrypoint.sh", "npm", "run", "server"]

FROM base AS studio
CMD ["bash", "scripts/cloud-entrypoint.sh", "bash", "scripts/studio-cloud.sh"]
