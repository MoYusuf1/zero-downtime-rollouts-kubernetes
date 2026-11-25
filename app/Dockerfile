FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
ARG VERSION=dev
ARG QUOTE_TOTAL=1200
RUN CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X main.version=${VERSION} -X main.quoteTotal=${QUOTE_TOTAL}" -o /quote .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /quote /quote
ENV STARTUP_SECONDS=5
EXPOSE 8080
USER nonroot
ENTRYPOINT ["/quote"]
