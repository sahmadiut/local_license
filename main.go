package main

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type Response struct {
	Status  string `json:"status"`
	Message string `json:"message,omitempty"`
}

var licenseKey string
var port string = "444" // default port
var certDir string = "/root/back_certs/"
var version string = "0.0.1" // version will be set during build

func main() {
	// Parse command line flags
	var showVersion bool
	flag.BoolVar(&showVersion, "version", false, "Show version and exit")
	flag.BoolVar(&showVersion, "v", false, "Show version and exit (shorthand)")
	flag.Parse()

	// Show version if requested
	if showVersion {
		fmt.Printf("local_license version %s\n", version)
		os.Exit(0)
	}

	// Parse remaining command line arguments
	args := flag.Args()
	if len(args) > 0 {
		licenseKey = args[0]
		fmt.Printf("License key set to: %s\n", licenseKey)
	} else {
		fmt.Println("No license key provided")
	}

	if len(args) > 1 {
		port = args[1]
		fmt.Printf("Port set to: %s\n", port)
	} else {
		fmt.Printf("Using default port: %s\n", port)
	}

	// Setup HTTP handlers
	http.HandleFunc("/", handleRequest)

	// Load certificates and create TLS config
	tlsConfig, err := loadCertificates()
	if err != nil {
		log.Printf("Warning: Could not load certificates: %v", err)
		log.Println("Starting HTTP server (non-SSL)")
		fmt.Printf("Server starting on HTTP port %s...\n", port)
		log.Fatal(http.ListenAndServe(":"+port, nil))
	} else {
		// Start HTTPS server
		server := &http.Server{
			Addr:      ":" + port,
			TLSConfig: tlsConfig,
		}
		fmt.Printf("Server starting on HTTPS port %s...\n", port)
		log.Fatal(server.ListenAndServeTLS("", ""))
	}
}

func loadCertificates() (*tls.Config, error) {
	// Read certificate directory
	files, err := ioutil.ReadDir(certDir)
	if err != nil {
		return nil, fmt.Errorf("cannot read certificate directory: %v", err)
	}

	var certificates []tls.Certificate
	certMap := make(map[string]string)  // domain -> cert file mapping
	keyMap := make(map[string]string)   // domain -> key file mapping
	domainMap := make(map[int][]string) // cert index -> domains mapping

	// Find certificate and key pairs
	for _, file := range files {
		if strings.HasSuffix(file.Name(), ".crt") {
			domain := strings.TrimSuffix(file.Name(), ".crt")
			certMap[domain] = filepath.Join(certDir, file.Name())
		}
		if strings.HasSuffix(file.Name(), ".key") {
			domain := strings.TrimSuffix(file.Name(), ".key")
			keyMap[domain] = filepath.Join(certDir, file.Name())
		}
	}

	// Load certificate pairs
	certIndex := 0
	for domain, certFile := range certMap {
		keyFile, exists := keyMap[domain]
		if !exists {
			log.Printf("Warning: No key file found for certificate %s", domain)
			continue
		}

		cert, err := tls.LoadX509KeyPair(certFile, keyFile)
		if err != nil {
			log.Printf("Warning: Could not load certificate pair for %s: %v", domain, err)
			continue
		}

		// Parse the certificate to get DNS names
		if len(cert.Certificate) > 0 {
			x509Cert, err := x509.ParseCertificate(cert.Certificate[0])
			if err != nil {
				log.Printf("Warning: Could not parse certificate for %s: %v", domain, err)
				continue
			}

			// Store domain names for this certificate
			var domains []string
			if x509Cert.Subject.CommonName != "" {
				domains = append(domains, x509Cert.Subject.CommonName)
			}
			domains = append(domains, x509Cert.DNSNames...)
			domainMap[certIndex] = domains

			log.Printf("Loaded certificate for domain: %s (DNS names: %v)", domain, domains)
		}

		certificates = append(certificates, cert)
		certIndex++
	}

	if len(certificates) == 0 {
		return nil, fmt.Errorf("no valid certificate pairs found")
	}

	// Create TLS config
	tlsConfig := &tls.Config{
		Certificates: certificates,
		GetCertificate: func(hello *tls.ClientHelloInfo) (*tls.Certificate, error) {
			if hello.ServerName == "" {
				// Return first certificate as default if no SNI
				return &certificates[0], nil
			}

			// Find matching certificate based on SNI
			for i, domains := range domainMap {
				for _, dnsName := range domains {
					if dnsName == hello.ServerName ||
						(strings.HasPrefix(dnsName, "*.") &&
							strings.HasSuffix(hello.ServerName, dnsName[1:])) {
						return &certificates[i], nil
					}
				}
			}

			// Return first certificate as default
			return &certificates[0], nil
		},
	}

	return tlsConfig, nil
}

func handleRequest(w http.ResponseWriter, r *http.Request) {
	// Log request headers and info
	log.Println("--------------------------------------")
	log.Printf("Request URL: %s", r.URL.Path)
	log.Printf("Request Method: %s", r.Method)
	log.Printf("Host: %s", r.Host)
	log.Printf("TLS: %v", r.TLS != nil)

	for name, values := range r.Header {
		for _, value := range values {
			log.Printf("Header %s: %s", name, value)
		}
	}

	// Set response headers
	w.Header().Set("Date", time.Now().UTC().Format("Mon, 02 Jan 2006 15:04:05 GMT"))
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Vary", "Accept-Encoding")
	w.Header().Set("X-XSS-Protection", "1; mode=block")
	w.Header().Set("Server", "ArvanCloud")
	w.Header().Set("Server-Timing", "total;dur=206")
	w.Header().Set("X-Cache", "BYPASS")
	w.Header().Set("X-Request-ID", fmt.Sprintf("%d", time.Now().UnixNano()))
	w.Header().Set("X-SID", "2092")
	w.Header().Set("Accept-Ranges", "bytes")

	// Handle different routes
	switch r.URL.Path {
	case "/license-validation2", "/renew-license":
		handleLicense(w, r)
	case "/heartbeat":
		fmt.Fprint(w, "Last seen updated successfully")
	default:
		// Default response
		response := Response{
			Status:  "VALID",
			Message: "License is valid",
		}
		jsonResponse, _ := json.Marshal(response)
		fmt.Fprint(w, string(jsonResponse))
	}
}

func handleLicense(w http.ResponseWriter, r *http.Request) {
	serverIP := r.URL.Query().Get("server_ip")
	if serverIP == "" {
		fmt.Fprint(w, "Invalid IP!")
		return
	}

	// If license key from command line exists, return it
	if licenseKey != "" {
		response := Response{Status: licenseKey}
		jsonResponse, _ := json.Marshal(response)
		fmt.Fprint(w, string(jsonResponse))
		log.Printf("License found for IP: %s, License: %s", serverIP, licenseKey)
	} else {
		// If no license key provided, return VALID
		response := Response{Status: "VALID"}
		jsonResponse, _ := json.Marshal(response)
		fmt.Fprint(w, string(jsonResponse))
		log.Printf("No license key provided, returning VALID for IP: %s", serverIP)
	}
}
