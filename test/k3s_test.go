package test

import (
	"fmt"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"k8s.io/client-go/tools/clientcmd"
	"net"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestTerraformHelloWorldExample(t *testing.T) {
	t.Parallel()

	tempTestFolder := test_structure.CopyTerraformFolderToTemp(t, "../", ".")

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, tempTestFolder)
		terraform.Destroy(t, terraformOptions)
	})

	// Deploy the example
	test_structure.RunTestStage(t, "setup", func() {
		terraformOptions, keyPair := configureTerraformOptions(t, tempTestFolder)

		// Save the options and key pair so later test stages can use them
		test_structure.SaveTerraformOptions(t, tempTestFolder, terraformOptions)
		test_structure.SaveSshKeyPair(t, tempTestFolder, keyPair)

		// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
		terraform.InitAndApply(t, terraformOptions)
	})

	// Make sure we can SSH to the public Instance directly from the public Internet and the private Instance by using
	// the public Instance as a jump host
	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, tempTestFolder)
		keyPair := test_structure.LoadSshKeyPair(t, tempTestFolder)

		// Run `terraform output` to get the IP of the instance
		publicIp := terraform.Output(t, terraformOptions, "k3s_server_ip")

		host := ssh.Host{
			Hostname:    publicIp,
			SshKeyPair:  keyPair,
			SshUserName: "core",
		}

		testServiceSetup(t, host)
		testKubernetes(tempTestFolder, t, host, publicIp)
	})
}

func testKubernetes(tempTestFolder string, t *testing.T, host ssh.Host, publicIp string) {
	kubeConfigPath := test_structure.FormatTestDataPath(tempTestFolder, "kube_config.yaml")
	downloadK3SConfig(t, host, kubeConfigPath)
	fixKubernetesHost(t, kubeConfigPath, publicIp)

	options := k8s.NewKubectlOptions("", kubeConfigPath, "default")
	k8s.WaitUntilAllNodesReady(t, options, 30, 15*time.Second)

	// TODO Test for ArgoCD & Dashboard
}

func fixKubernetesHost(t *testing.T, kubeConfigPath string, publicIp string) {
	loadedConf := k8s.LoadConfigFromPath(kubeConfigPath)
	rawConf, err := loadedConf.RawConfig()
	for _, cluster := range rawConf.Clusters {
		clusterAddress, err := url.Parse(cluster.Server)
		if err != nil {
			t.Fatal(err)
		}

		clusterAddress.Host = net.JoinHostPort(publicIp, clusterAddress.Port())

		cluster.Server = clusterAddress.String()
	}

	err = clientcmd.ModifyConfig(loadedConf.ConfigAccess(), rawConf, false)
	if err != nil {
		t.Fatal(err)
	}
}

func downloadK3SConfig(t *testing.T, host ssh.Host, kubeConfigPath string) {
	// Download cluster config https://docs.k3s.io/cluster-access

	kubeConfigFile, err := os.Create(kubeConfigPath)
	if err != nil {
		t.Fatal(err)
	}

	defer func(kubeConfigFile *os.File) {
		err := kubeConfigFile.Close()
		if err != nil {
			t.Fatal(err)
		}
	}(kubeConfigFile)

	ssh.ScpFileFrom(t, host, "/etc/rancher/k3s/k3s.yaml", kubeConfigFile, true)
}

func configureTerraformOptions(t *testing.T, tempTestFolder string) (*terraform.Options, *ssh.KeyPair) {
	keyPair := ssh.GenerateRSAKeyPair(t, 4096)

	// Construct the terraform options with default retryable errors to handle the most common retryable errors in
	// terraform testing.
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: tempTestFolder,

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"ssh_public_key": keyPair.PublicKey,
		},
	})

	return terraformOptions, keyPair
}

// TODO This must be run on every node!
func testServiceSetup(t *testing.T, host ssh.Host) {

	// Run a simple echo command on the server
	runSSHCommand(t, host, "echo -n Test", "Test", 30, 5*time.Second)

	// Validate k3s ostree installation service
	runSSHCommand(t, host, "systemctl show rpm-ostree-install-k3s-selinux -p ActiveState,SubState,Result", "Result=success\nActiveState=active\nSubState=exited", 60, 5*time.Second)

	// Validate k3s installation service
	runSSHCommand(t, host, "systemctl show install-k3s -p ActiveState,SubState,Result", "Result=success\nActiveState=active\nSubState=exited", 60, 5*time.Second)

}

func runSSHCommand(t *testing.T, host ssh.Host, command string, expectedText string, maxRetries int, sleepBetweenRetries time.Duration) {
	description := fmt.Sprintf("SSH to host %s", host.Hostname)

	// Verify that we can SSH to the Instance and run commands
	retry.DoWithRetry(t, description, maxRetries, sleepBetweenRetries, func() (string, error) {
		actualText, err := ssh.CheckSshCommandE(t, host, command)

		if err != nil {
			return "", err
		}

		if strings.TrimSpace(actualText) != expectedText {
			return "", fmt.Errorf("expected SSH command to return '%s' but got '%s'", expectedText, actualText)
		}

		return "", nil
	})
}
