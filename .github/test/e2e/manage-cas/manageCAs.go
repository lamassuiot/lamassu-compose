package cas

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"io/ioutil"
	"math/big"
	"os"
	"time"

	"github.com/globalsign/pemfile"
	"github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/jakehl/goid"

	caDTO "github.com/lamassuiot/lamassuiot/pkg/ca/common/dto"
	"github.com/lamassuiot/lamassuiot/pkg/utils/server/filters"
	client "github.com/lamassuiot/lamassuiot/test/e2e/utils/clients"
)

func ManageCAs(caNumber int, scaleIndex int, certPath string, domain string) (caDTO.Cert, error) {
	var logger log.Logger
	logger = log.NewJSONLogger(os.Stdout)
	logger = level.NewFilter(logger, level.AllowDebug())
	logger = log.With(logger, "ts", log.DefaultTimestampUTC)
	logger = log.With(logger, "caller", log.DefaultCaller)

	caClient, err := client.LamassuCaClient(certPath, domain)
	if err != nil {
		return caDTO.Cert{}, err
	}
	var createCa caDTO.GetCasResponse
	for i := 0; i < caNumber; i++ {
		caName := goid.NewV4UUID().String()

		_, err = caClient.CreateCA(context.Background(), caDTO.Pki, caName, caDTO.PrivateKeyMetadata{KeyType: "RSA", KeyBits: 2048}, caDTO.Subject{CommonName: caName}, 365*time.Hour, 30*time.Hour)
		if err != nil {
			level.Error(logger).Log("err", err)
			return caDTO.Cert{}, err
		}
		createCa, err = caClient.GetCAs(context.Background(), caDTO.Pki, filters.QueryParameters{Pagination: filters.PaginationOptions{Limit: 50, Offset: 0}})
		if err != nil {
			return caDTO.Cert{}, err
		}

	}
	err = caClient.DeleteCA(context.Background(), caDTO.Pki, createCa.CAs[caNumber-1].Name)
	if err != nil {
		return caDTO.Cert{}, err
	}
	err = CreateCertKey()
	if err != nil {
		level.Error(logger).Log("err", err)
		return caDTO.Cert{}, err
	}
	certContent, err := ioutil.ReadFile("./ca.crt")
	if err != nil {
		level.Error(logger).Log("err", err)
		return caDTO.Cert{}, err
	}
	cpb, _ := pem.Decode(certContent)

	importcrt, err := x509.ParseCertificate(cpb.Bytes)
	if err != nil {
		level.Error(logger).Log("err", err)
		return caDTO.Cert{}, err
	}
	privateKey, err := pemfile.ReadPrivateKey("./ca.key")
	if err != nil {
		level.Error(logger).Log("err", err)
		return caDTO.Cert{}, err
	}
	ca, err := caClient.ImportCA(context.Background(), caDTO.Pki, importcrt.Subject.CommonName, *importcrt, caDTO.PrivateKey{KeyType: caDTO.RSA, Key: privateKey}, 30*time.Hour)
	if err != nil {
		level.Error(logger).Log("err", err)
		return caDTO.Cert{}, err
	}
	os.Remove("./ca.crt")
	os.Remove("./ca.key")
	return ca, nil
}
func CreateCertKey() error {
	serialnumber, err := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 160))
	if err != nil {
		return err
	}
	ca := &x509.Certificate{
		SerialNumber: serialnumber,
		Subject: pkix.Name{
			Organization:       []string{"IKL"},
			Country:            []string{"ES"},
			Province:           []string{"Gipuzkoa"},
			Locality:           []string{"Arrasate"},
			OrganizationalUnit: []string{"ZPD"},
			CommonName:         goid.NewV4UUID().String(),
		},
		NotBefore:             time.Now(),
		NotAfter:              time.Now().AddDate(10, 0, 0),
		IsCA:                  true,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth, x509.ExtKeyUsageServerAuth},
		KeyUsage:              x509.KeyUsageDigitalSignature | x509.KeyUsageCertSign,
		BasicConstraintsValid: true,
	}
	caPrivKey, err := rsa.GenerateKey(rand.Reader, 4096)
	if err != nil {
		return err
	}
	caBytes, err := x509.CreateCertificate(rand.Reader, ca, ca, &caPrivKey.PublicKey, caPrivKey)
	if err != nil {
		return err
	}
	caPEM := new(bytes.Buffer)
	pem.Encode(caPEM, &pem.Block{
		Type:  "CERTIFICATE",
		Bytes: caBytes,
	})

	ioutil.WriteFile("./ca.crt", caPEM.Bytes(), 0777)

	caPrivKeyPEM := new(bytes.Buffer)
	pem.Encode(caPrivKeyPEM, &pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: x509.MarshalPKCS1PrivateKey(caPrivKey),
	})
	ioutil.WriteFile("./ca.key", caPrivKeyPEM.Bytes(), 0777)
	return nil
}
