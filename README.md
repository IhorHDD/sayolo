# sayolo
sayolo

1) Things required for Pulumi running;
For appropriate running pulumi, I installed pulumi binary on Mac. For correct infrastructure deploying inside AWS appropriate secrets has been exported:
-  export AWS_SECRET_ACCESS_KEY=***
- export AWS_ACCESS_KEY_ID=***
When stuff for accessing AWS is specified, all necessary libraries for running Python script should be specified in the requirements.txt file
The next step is installing all necessary libraries, for that step command below should be run:
venv/bin/pip install -r requirements.txt

So we ready for creating and configure infrastructure in AWS (actually Pulumi can work with different providers).

2) Deploying infrastructure;
    1. We should import all the necessary libraries to the Python, which will be used during the script execution;
    2. Need to created cluster, where the necessary quantity of instances and their types should be specified;
    
        cluster = eks.Cluster(
            "cluster",
            instance_type="c5.xlarge",
            desired_capacity=4,
            min_size=2,
            max_size=4,
        )
    
    3. Creating ECR repo for containers storing and getting secret for publishing container;
    
        sayolo = aws.ecr.Repository("sayolo",
        image_scanning_configuration=aws.ecr.RepositoryImageScanningConfigurationArgs(
            scan_on_push=True,
        ),
        image_tag_mutability="MUTABLE")

        token = aws.ecr.get_authorization_token()

        def getRegistryInfo(rid):
            creds = aws.ecr.get_credentials(registry_id=rid)
            decoded = base64.b64decode(creds.authorization_token).decode()
            parts = decoded.split(':')
            if len(parts) != 2:
                raise Exception("Invalid credentials")
            return docker.ImageRegistry(creds.proxy_endpoint, parts[0], parts[1])
        image_name = sayolo.repository_url
        registry_info = sayolo.registry_id.apply(getRegistryInfo) 
    
    4. Preparing docker image (Docker file should be prepared previously with the all necessary installation) with appropriate start web-page for Nginx and push it to the created on the 3rd step ECR repo;
    
        image = docker.Image('sayolo_build',
            build='.',
            image_name=image_name,
            registry=registry_info,
        )

    4. Installation Deployment and Frontend services inside previously created cluster;

        config = pulumi.Config()
        is_minikube = config.require_bool("isMinikube")

        app_name = "nginx"
        app_labels = { "app": app_name }

        deployment = Deployment(
            app_name,
            spec={
                "selector": { "match_labels": app_labels },
                "replicas": 1,
                "template": {
                    "metadata": { "labels": app_labels },
                    "spec": { "containers": [{ "name": app_name, "image": "nginx" }] }
                }
            })

        frontend = Service(
            app_name,
            metadata={
                "labels": deployment.spec["template"]["metadata"]["labels"],
            },
            spec={
                "type": "ClusterIP" if is_minikube else "LoadBalancer",
                "ports": [{ "port": 80, "target_port": 80, "protocol": "TCP" }],
                "selector": app_labels,
            })

        result = None
        if is_minikube:
            result = frontend.spec.apply(lambda v: v["cluster_ip"] if "cluster_ip" in v else None)
        else:
            ingress = frontend.status.apply(lambda v: v["load_balancer"]["ingress"][0] if "load_balancer" in v else None)
            if ingress is not None:
                result = ingress.apply(lambda v: v["ip"] if "ip" in v else v["hostname"])

        pulumi.export("ip", result)

Screenshots from the AWS console can be found in the Screenshot folder.

Below you can find information from the console output during pulumi up the process:

➜  sayolo git:(main) ✗ pulumi up                        
Previewing update (dev)

View Live: https://app.pulumi.com/Kanivets/repo4/dev/previews/3e60c0fc-a6d5-4094-9070-227e31effa55

     Type                                   Name                                       Plan       
 +   pulumi:pulumi:Stack                    repo4-dev                                  create     
 +   pulumi:pulumi:Stack                    repo4-dev                                  create.    
 +   pulumi:pulumi:Stack                    repo4-dev                                  create     
 +   ├─ eks:index:Cluster                   cluster                                    create     
 +   │  ├─ eks:index:ServiceRole            cluster-eksRole                            create     
 +   │  │  ├─ aws:iam:Role                  cluster-eksRole-role                       create     
 +   │  │  ├─ aws:iam:RolePolicyAttachment  cluster-eksRole-90eb1c99                   create     
 +   │  │  └─ aws:iam:RolePolicyAttachment  cluster-eksRole-4b490823                   create     
 +   │  ├─ eks:index:ServiceRole            cluster-instanceRole                       create     
 +   │  │  ├─ aws:iam:Role                  cluster-instanceRole-role                  create     
 +   │  │  ├─ aws:iam:RolePolicyAttachment  cluster-instanceRole-3eb088f2              create     
 +   │  │  ├─ aws:iam:RolePolicyAttachment  cluster-instanceRole-e1b295bd              create     
 +   │  │  └─ aws:iam:RolePolicyAttachment  cluster-instanceRole-03516f97              create     
 +   │  ├─ eks:index:RandomSuffix           cluster-cfnStackName                       create     
 +   │  ├─ aws:iam:InstanceProfile          cluster-instanceProfile                    create     
 +   │  ├─ aws:ec2:SecurityGroup            cluster-eksClusterSecurityGroup            create     
 +   │  ├─ aws:ec2:SecurityGroupRule        cluster-eksClusterInternetEgressRule       create     
 +   │  ├─ aws:eks:Cluster                  cluster-eksCluster                         create     
 +   │  ├─ eks:index:VpcCni                 cluster-vpc-cni                            create     
 +   │  ├─ aws:ec2:SecurityGroup            cluster-nodeSecurityGroup                  create     
 +   │  ├─ pulumi:providers:kubernetes      cluster-eks-k8s                            create     
 +   │  ├─ aws:ec2:SecurityGroupRule        cluster-eksExtApiServerClusterIngressRule  create     
 +   │  ├─ aws:ec2:SecurityGroupRule        cluster-eksNodeIngressRule                 create     
 +   │  ├─ aws:ec2:SecurityGroupRule        cluster-eksNodeInternetEgressRule          create     
 +   │  ├─ aws:ec2:SecurityGroupRule        cluster-eksClusterIngressRule              create     
 +   │  ├─ kubernetes:core/v1:ConfigMap     cluster-nodeAccess                         create     
 +   │  ├─ aws:ec2:SecurityGroupRule        cluster-eksNodeClusterIngressRule          create     
 +   │  ├─ aws:ec2:LaunchConfiguration      cluster-nodeLaunchConfiguration            create     
 +   │  ├─ aws:cloudformation:Stack         cluster-nodes                              create     
 +   │  └─ pulumi:providers:kubernetes      cluster-provider                           create     
 +   ├─ kubernetes:apps/v1:Deployment       nginx                                      create     
 +   └─ kubernetes:core/v1:Service          nginx                                      create     
 
Resources:
    + 32 to create

Do you want to perform this update? yes
Updating (dev)

View Live: https://app.pulumi.com/Kanivets/repo4/dev/updates/16

     Type                                   Name                                       Status       Info
 +   pulumi:pulumi:Stack                    repo4-dev                                  creating.    
 +   pulumi:pulumi:Stack                    repo4-dev                                  creating     
 +   ├─ eks:index:Cluster                   cluster                                    created     
 +   │  ├─ eks:index:ServiceRole            cluster-instanceRole                       created     
 +   │  │  ├─ aws:iam:Role                  cluster-instanceRole-role                  created     
 +   │  │  ├─ aws:iam:RolePolicyAttachment  cluster-instanceRole-3eb088f2              created     
 +   │  │  ├─ aws:iam:RolePolicyAttachment  cluster-instanceRole-e1b295bd              created     
 +   │  │  └─ aws:iam:RolePolicyAttachment  cluster-instanceRole-03516f97              created     
 +   │  ├─ eks:index:ServiceRole            cluster-eksRole                            created     
 +   │  │  ├─ aws:iam:Role                  cluster-eksRole-role                       created     
 +   │  │  ├─ aws:iam:RolePolicyAttachment  cluster-eksRole-4b490823                   created     
 +   │  │  └─ aws:iam:RolePolicyAttachment  cluster-eksRole-90eb1c99                   created     
 +   │  ├─ eks:index:RandomSuffix           cluster-cfnStackName                       created     
 +   │  ├─ aws:ec2:SecurityGroup            cluster-eksClusterSecurityGroup            created     
 +   │  ├─ aws:iam:InstanceProfile          cluster-instanceProfile                    created     
 +   │  ├─ aws:ec2:SecurityGroupRule        cluster-eksClusterInternetEgressRule       created     
 +   │  ├─ aws:eks:Cluster                  cluster-eksCluster                         created     
 +   │  ├─ aws:ec2:SecurityGroup            cluster-nodeSecurityGroup                  created     
 +   │  ├─ aws:ec2:SecurityGroupRule        cluster-eksNodeInternetEgressRule          created     
 +   │  ├─ aws:ec2:SecurityGroupRule        cluster-eksExtApiServerClusterIngressRule  created     
 +   │  ├─ aws:ec2:SecurityGroupRule        cluster-eksNodeIngressRule                 created     
 +   │  ├─ aws:ec2:SecurityGroupRule        cluster-eksClusterIngressRule              created     
 +   │  ├─ aws:ec2:SecurityGroupRule        cluster-eksNodeClusterIngressRule          created     
 +   │  ├─ aws:ec2:LaunchConfiguration      cluster-nodeLaunchConfiguration            created     
 +   │  ├─ eks:index:VpcCni                 cluster-vpc-cni                            created     
 +   │  ├─ pulumi:providers:kubernetes      cluster-eks-k8s                            created     
 +   │  ├─ kubernetes:core/v1:ConfigMap     cluster-nodeAccess                         created     
 +   │  ├─ aws:cloudformation:Stack         cluster-nodes                              created     
 +   │  └─ pulumi:providers:kubernetes      cluster-provider                           created     
 +   ├─ aws:ecr:Repository                  sayolo                                     created     
 +   ├─ kubernetes:apps/v1:Deployment       nginx                                      created     
 +   └─ kubernetes:core/v1:Service          nginx                                      created     
 
Diagnostics:
  docker:image:Image (sayolo_build):
    warning: #1 [internal] load build definition from Dockerfile
    #1 sha256:a2fffe20563da24f42efafd674123a1eafc3234eae16c6f71a5f842a684caee7
    #1 transferring dockerfile: 36B done
    #1 DONE 0.0s
    
    #2 [internal] load .dockerignore
    #2 sha256:c84f915abda84dde76201a141d24e0cdf6f6ae29820de7816524bc29b207c5ca
    #2 transferring context: 2B done
    #2 DONE 0.0s
    
    #3 [internal] load metadata for docker.io/library/nginx:latest
    #3 sha256:06c466a4eb6821b81bd3e48610e5f38dab858b1e9acb01d6e2f6b11c8fabe6bc
    #3 DONE 0.0s
    
    #4 [1/2] FROM docker.io/library/nginx
    #4 sha256:62549b609c62be5d4a072c8b1697ba6e0f40e59bf6b340565f5132922031518b
    #4 DONE 0.0s
    
    #5 [2/2] RUN echo "<h1>Hello, World -- from Pulumi!</h1>" >     /usr/share/nginx/html/index.html
    #5 sha256:275e239034ea15795e2fea35ca4072a5bec50b2a6cd3c987d0f63bcb73060d3f
    #5 CACHED
    
    #6 exporting to image
    #6 sha256:e8c613e07b0b7ff33893b694f7759a10d42e180f2b4dc349fb57dc6b71dcab00
    #6 exporting layers done
    #6 writing image sha256:808063773f93e937dc03fca8386ab47639f442ca6a0ca311b249fcb836051e2d done
    #6 naming to 841260249935.dkr.ecr.us-west-2.amazonaws.com/sayolo-cac13ee done
    #6 DONE 0.0s
 
Outputs:
    baseImageName: "841260249935.dkr.ecr.us-west-2.amazonaws.com/sayolo-cac13ee"
    fullImageName: "841260249935.dkr.ecr.us-west-2.amazonaws.com/sayolo-cac13ee:808063773f93e937dc03fca8386ab47639f442ca6a0ca311b249fcb836051e2d"
    ip           : "10.97.70.140"
    kubeconfig   : {
        apiVersion     : "v1"
        clusters       : [
            [0]: {
                cluster: {
                    certificate-authority-data: "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN5RENDQWJDZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJeE1EUXhNakl3TURFd09Gb1hEVE14TURReE1ESXdNREV3T0Zvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTmN2CjlKalk3bHh2aEk0NmpmTjZzUTNnejRUZjV4NmpQRUcxTkoyNzdaS3NySytsVWEwZllNaGMwOTdlVnRsb1JGYm4KYzBVV2lSK2FkQ0ozOGNZWEpUeFRvU05IWkZQNU5sdmJ2OC9CVTMrT2lwRG9vRHR1SEdPeVNpRVJhR0syaWRoQwpHMytSeWYrdkd5U2ZZR0hyRWpJNHlscUdsRDJFemhtOStoTlJVL1R6UHAyVE9aVVpHOE5DN0hhNjZlMjJaemhQCjFHMHVMN2kyOThrU09TMkw4MklhRXRkNVNzb2xhaXBhMHFEZWlDVE9CV2ZrTXFZSFBtTS91Si94dXNzMmtYclgKN3J4RCs3VnVRUStwN3RmTjdNNisvckE4RWxBbUl1Tlhqc3JZOStaQUpiQVhKa1Y5U3lxUUhHY1ZTYWtDT3FoMwpiNHBiWVVQNjJJZThaN0tyVW9zQ0F3RUFBYU1qTUNFd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFBMHl1RXVCYmFXZkIwcU9vS3VGYWt5bE0zaVUKMjhqdUpza1p0U2dpUXA5dnpvV3JXaXpZNjdBMEx0czVWNW5uOEo3ZG5iTk9acDJmV1BvU1ZPb0hJSVNjNWlQVQpySENwR1ByWWRUZnJVSS9yN04zV3hPbkdxNUhSNXVXUHhmdUdTaURBWlVybjFNVFdOamYvTVZBVFVkbFI0eFVGCkRRbjBVQzRXQlRIUlM5WTFtQTlQcmdnNDdXaE1KQUpHZnNwL1JUK0VRTUhhVWRXbWNENXYwbFNEUHBUMGlKazAKSU15RFhrTkluTjY0ckw4elRDM2N2T2o0VDZGeFBLT1loSTlXeWFYU0pVVGxGRGFFQ3gzenJ0VDB3NmVpSG8zWApFUGxxZnBSSUFiVG5oYUw1NGxEbFlSOFR5aDQ4eGlUZjRBR24vZ01qNHQ5SUxvSjRaYVhqaGx5VVFOcz0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
                    server                    : "https://57C9DC7385707500DDB39C93B5D57866.gr7.us-west-2.eks.amazonaws.com"
                }
                name   : "kubernetes"
            }
        ]
        contexts       : [
            [0]: {
                context: {
                    cluster: "kubernetes"
                    user   : "aws"
                }
                name   : "aws"
            }
        ]
        current-context: "aws"
        kind           : "Config"
        users          : [
            [0]: {
                name: "aws"
                user: {
                    exec: {
                        apiVersion: "client.authentication.k8s.io/v1alpha1"
                        args      : [
                            [0]: "eks"
                            [1]: "get-token"
                            [2]: "--cluster-name"
                            [3]: "cluster-eksCluster-66db232"
                        ]
                        command   : "aws"
                    }
                }
            }
        ]
    }

Resources:
    + 32 created

Duration: 13m1s

➜  sayolo git:(main) ✗ 

