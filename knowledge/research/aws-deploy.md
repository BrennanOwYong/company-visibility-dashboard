# AWS Deploy Research — SiteTether Receiver

**Date:** 2026-06-27
**Scope:** Non-technical user deploys Receiver (Tailscale + headful Chromium + Node.js) via AWS console, region us-east-1.

---

## Recommended deploy mechanism

**CloudFormation quick-create URL** (template hosted on S3). One click opens the CloudFormation console with the template pre-loaded. The user fills in the Tailscale auth key, clicks Create Stack, and waits. The pairing data appears in the stack's Outputs tab when setup completes.

Rationale over prebuilt AMI:
- A custom AMI must be re-baked on every Receiver update and per-region copied. The CloudFormation + user-data approach pulls the latest software at boot via package managers.
- AWS Marketplace AMI listing requires a formal Marketplace publishing process — not appropriate for v1 BYO-AWS.
- The quick-create URL is the documented one-click path. Official docs: [cfn-console-create-stacks-quick-create-links](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stacks-quick-create-links.html).

### Quick-create URL format

```
https://{region}.console.aws.amazon.com/cloudformation/home?region={region}#/stacks/create/review?templateURL={s3-url}&stackName={name}
```

Concrete example (us-east-1):

```
https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https://s3.us-east-1.amazonaws.com/sitether-deploy/receiver.yaml&stackName=SiteTetherReceiver
```

Rules:
- `templateURL` must point to an S3 object (HTTPS, path-style or virtual-hosted).
- `param_{Name}` pre-populates non-secret parameters. Parameters with `NoEcho: true` are silently ignored by the URL; the user types them into the console form.
- The `#` fragment must not be URL-encoded.

---

## Chosen instance + cost

| Instance | vCPU | RAM | Arch | On-Demand/hr | On-Demand/month | Free Tier |
|----------|------|-----|------|-------------|-----------------|-----------|
| t4g.nano | 2 | 0.5 GB | ARM64 | $0.0042 | ~$3.07 | No |
| **t4g.micro** | **2** | **1 GB** | **ARM64** | **$0.0084** | **~$6.13** | **Yes** |
| t3.micro | 2 | 1 GB | x86_64 | $0.0104 | ~$7.59 | Yes |
| t2.micro | 1 | 1 GB | x86_64 | $0.0116 | ~$8.47 | Yes |

**Chosen: t4g.micro** at $0.0084/hr (~$6.13/month on-demand).

- t4g.nano (0.5 GB) is below the viable floor for headful Chromium. A single Chromium renderer process plus OS and Tailscale will OOM under any real page load.
- t4g.micro (1 GB) is the minimum viable RAM. Chromium + Tailscale + Node.js fit within 1 GB with a single tab and no unnecessary extensions.
- t4g is cheaper than t3/t2 and covers Free Tier (750 hrs/month). ARM64 (Graviton) requires ARM64 AMI and ARM64 packages; Node.js, Tailscale, and Chromium-browser all publish ARM64 binaries for Ubuntu 22.04/24.04.
- **For Free Tier users:** t2.micro is the classic free-tier instance and requires no architecture decision (x86_64). Swap `InstanceType` to `t2.micro` to avoid any ARM64 package concerns during early testing.

---

## CloudFormation template skeleton

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: SiteTether Receiver — Tailscale + headful Chromium + Node.js server

Parameters:

  TailscaleAuthKey:
    Type: String
    NoEcho: true
    Description: >
      Tailscale auth key (Settings → Keys → Generate auth key).
      Mark it ephemeral + pre-approved in the Tailscale console.
    MinLength: 1

  InstanceType:
    Type: String
    Default: t4g.micro
    AllowedValues:
      - t4g.micro
      - t4g.nano
      - t3.micro
      - t2.micro
    Description: EC2 instance type. t4g.micro is cheapest viable. t2.micro qualifies for Free Tier.

  LatestAmiId:
    Type: AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>
    # Ubuntu 22.04 LTS ARM64 (Graviton) — resolves to the latest AMI at stack create time
    # Switch to /aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id for x86
    Default: /aws/service/canonical/ubuntu/server/22.04/stable/current/arm64/hvm/ebs-gp2/ami-id

Resources:

  ReceiverInstanceRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: ReceiverCfnSignal
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action: cloudformation:SignalResource
                Resource: !Sub 'arn:aws:cloudformation:${AWS::Region}:${AWS::AccountId}:stack/${AWS::StackName}/*'

  ReceiverInstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Roles:
        - !Ref ReceiverInstanceRole

  ReceiverSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: SiteTether Receiver — no inbound, Tailscale handles all connectivity
      # No SecurityGroupIngress property → zero inbound rules
      # No SecurityGroupEgress property → AWS default allow-all outbound remains

  ReceiverWaitHandle:
    Type: AWS::CloudFormation::WaitConditionHandle

  ReceiverWaitCondition:
    Type: AWS::CloudFormation::WaitCondition
    DependsOn: ReceiverInstance
    Properties:
      Handle: !Ref ReceiverWaitHandle
      Timeout: '900'  # 15 minutes for package installs
      Count: 1

  ReceiverInstance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: !Ref InstanceType
      ImageId: !Ref LatestAmiId
      IamInstanceProfile: !Ref ReceiverInstanceProfile
      SecurityGroupIds:
        - !GetAtt ReceiverSecurityGroup.GroupId
      # Uses the account's default VPC and a default subnet; no VPC resource needed
      Tags:
        - Key: Name
          Value: SiteTether-Receiver
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash -xe
          exec > >(tee /var/log/receiver-setup.log | logger -t receiver-setup) 2>&1

          # ── 1. System packages ──────────────────────────────────────────
          export DEBIAN_FRONTEND=noninteractive
          apt-get update -y
          apt-get install -y curl gnupg ca-certificates unzip

          # ── 2. Install Tailscale ────────────────────────────────────────
          curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg \
            | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
          curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list \
            | tee /etc/apt/sources.list.d/tailscale.list
          apt-get update -y
          apt-get install -y tailscale

          # ── 3. Join Tailscale with the auth key ────────────────────────
          # --accept-routes: receive routes from other devices
          # --ssh: enable Tailscale SSH for future admin without inbound SG rules
          tailscale up --authkey="${TailscaleAuthKey}" --hostname=sitether-receiver \
            --ssh --accept-routes --timeout=60s

          # Capture the Tailscale IP and device name for the pairing code
          TAILSCALE_IP=$(tailscale ip -4)
          TAILSCALE_HOSTNAME=$(tailscale status --json | python3 -c \
            "import sys,json; s=json.load(sys.stdin); print(s['Self']['DNSName'].rstrip('.'))")

          # ── 4. Install Node.js (LTS, ARM64) ────────────────────────────
          curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
          apt-get install -y nodejs

          # ── 5. Install headful Chromium ─────────────────────────────────
          # chromium-browser installs ARM64 build on Ubuntu 22.04
          apt-get install -y chromium-browser xvfb

          # Virtual framebuffer (headful without a physical display)
          cat > /etc/systemd/system/xvfb.service << 'XVFB_EOF'
          [Unit]
          Description=Xvfb virtual framebuffer
          After=network.target

          [Service]
          ExecStart=/usr/bin/Xvfb :99 -screen 0 1280x720x24
          Restart=always
          Environment=DISPLAY=:99

          [Install]
          WantedBy=multi-user.target
          XVFB_EOF
          systemctl enable xvfb
          systemctl start xvfb

          # ── 6. Install the Receiver service ────────────────────────────
          # TODO: replace with actual Receiver install (npm package or git clone)
          mkdir -p /opt/sitether-receiver
          # npm install -g @sitether/receiver  # or: git clone + npm ci
          # Placeholder: a minimal Node.js process to hold the port
          cat > /opt/sitether-receiver/index.js << 'NODE_EOF'
          const http = require('http');
          const server = http.createServer((req, res) => {
            res.end('SiteTether Receiver running\n');
          });
          server.listen(3001, '127.0.0.1');
          console.log('Receiver listening on 127.0.0.1:3001');
          NODE_EOF

          cat > /etc/systemd/system/sitether-receiver.service << 'SVC_EOF'
          [Unit]
          Description=SiteTether Receiver
          After=network.target xvfb.service tailscaled.service

          [Service]
          ExecStart=/usr/bin/node /opt/sitether-receiver/index.js
          Restart=on-failure
          Environment=DISPLAY=:99
          WorkingDirectory=/opt/sitether-receiver

          [Install]
          WantedBy=multi-user.target
          SVC_EOF
          systemctl enable sitether-receiver
          systemctl start sitether-receiver

          # ── 7. Generate pairing code and signal CloudFormation ─────────
          # The pairing code encodes the Tailscale address + a short-lived HMAC key
          # TODO: replace with actual pairing-code generator from the Receiver package
          PAIRING_CODE="${!TAILSCALE_IP}:${!TAILSCALE_HOSTNAME}"

          # Signal success + send pairing data to WaitCondition Output
          curl -X PUT -H 'Content-Type:' \
            --data-binary "{\"Status\":\"SUCCESS\",\"Reason\":\"Receiver ready\",\"UniqueId\":\"boot\",\"Data\":\"$PAIRING_CODE\"}" \
            '${ReceiverWaitHandle}'

Outputs:
  PairingCode:
    Description: >
      Copy this value and paste it into the SiteTether Chrome extension to pair
      your laptop with this Receiver. The pairing code expires after ~10 minutes.
    Value: !GetAtt ReceiverWaitCondition.Data

  InstanceId:
    Description: EC2 instance ID (use to SSH via Tailscale SSH or check logs)
    Value: !Ref ReceiverInstance

  TailscaleHostname:
    Description: The Receiver appears under this name in your Tailscale admin console
    Value: sitether-receiver
```

---

## Notes on the template

**NoEcho behavior:** The Tailscale auth key is masked in the console and all API responses. It IS available to the instance via `!Sub` interpolation in UserData. Never echo it into an Output (CloudFormation does not mask NoEcho values in Outputs).

**WaitCondition.Data shape:** The Output value from `!GetAtt ReceiverWaitCondition.Data` is a JSON string: `{"boot": "actual-pairing-code"}`. The builder's pairing-code parser must unwrap this JSON envelope.

**AMI parameter:** The `AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>` type resolves at stack-create time to the latest Ubuntu 22.04 ARM64 AMI. Switch the `Default` path to the amd64 path when using t2.micro or t3.micro.

**VPC:** No `AWS::EC2::VPC` resource is needed. Omitting `SubnetId` on the instance causes CloudFormation to place it in the default VPC's default subnet automatically.

**Tailscale SSH:** `--ssh` on `tailscale up` enables SSH access over the Tailscale network without any inbound security group rule. This is how the builder or admin accesses the instance for debugging — no bastion, no SSH port open.

**`!Sub` and `!` escaping:** In a `!Sub` block, `${}` is interpolated as a CloudFormation variable. To emit a literal `$` in the shell script, use `${!VAR}` (the `!` tells `!Sub` to treat it as a literal shell variable reference, not a CloudFormation ref).

---

## Security group posture

Zero inbound rules. The security group has no `SecurityGroupIngress` property, which means AWS allows no inbound traffic by default. No `SecurityGroupEgress` property means the AWS default allow-all outbound rule remains in effect. Tailscale makes only outbound UDP (port 41641, WireGuard) and HTTPS (443) connections to Tailscale coordination servers. No public IP is required or assigned.

Optional hardening: add explicit `SecurityGroupEgress` rules for UDP 41641 and TCP 443/80 only, which removes the default allow-all. This tightens egress but adds maintenance burden if Tailscale changes relay port behavior.

---

## Surfacing the pairing code

**CloudFormation Outputs tab** (recommended for non-technical users). After the stack reaches `CREATE_COMPLETE`, the console's Outputs tab shows the `PairingCode` value. The user copies it and pastes it into the extension. No CLI, no SSH, no extra navigation.

Alternative channels (not recommended for v1):
- **EC2 "Get System Log"**: EC2 console → Instances → Actions → Monitor and troubleshoot → Get system log. Shows boot output. Requires navigating away from CloudFormation and parsing raw logs. Too technical.
- **SSM Parameter Store**: Instance writes to `/sitether/receiver/login-url` via `aws ssm put-parameter`. Requires reading it back via CLI or a separate console page. Cannot be surfaced as a CloudFormation Output (dynamic SSM refs resolve at stack-create time, before boot completes).

---

## User-data bootstrap outline

1. Apt update + install curl, gnupg, ca-certificates.
2. Add Tailscale apt repo (Tailscale's official install script or the keyring approach shown above).
3. `tailscale up --authkey=... --hostname=sitether-receiver --ssh` — joins the tailnet, enables Tailscale SSH.
4. Capture `tailscale ip -4` and the device's DNS name for the pairing code.
5. Install Node.js LTS via NodeSource apt repo.
6. Install `chromium-browser` + `xvfb` (virtual framebuffer for headful rendering without a display).
7. Start `xvfb.service` and `sitether-receiver.service` under systemd.
8. Generate pairing code (Tailscale address + short-lived HMAC key from the Receiver package).
9. Signal CloudFormation WaitCondition with the pairing code in the `Data` field.

---

## Teardown

Delete the CloudFormation stack from the console (Stacks → select stack → Delete). EC2 instance is terminated, security group is deleted, IAM role and instance profile are deleted. No resources persist (no EBS `DeletionPolicy: Retain`, no Elastic IP, no S3 bucket). Tailscale device remains in the user's tailnet admin console; the user should remove it manually from `login.tailscale.com/admin/machines` after teardown. On-demand billing stops when the instance terminates (typically within minutes of deletion).

**Leftover cost warning:** If the stack deletion fails partway (e.g., a manually added resource blocks deletion), the EC2 instance may continue running. The user should check the EC2 console after deletion and confirm the instance shows `terminated`.

---

## Sources

- CloudFormation quick-create links: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stacks-quick-create-links.html — retrieved 2026-06-27
- EC2 user-data: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html — retrieved 2026-06-27
- CloudFormation Parameters (NoEcho): https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/parameters-section-structure.html — retrieved 2026-06-27
- CloudFormation Outputs: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/outputs-section-structure.html — retrieved 2026-06-27
- AWS::EC2::SecurityGroup resource: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-ec2-securitygroup.html — retrieved 2026-06-27
- WaitCondition: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-waitcondition.html — retrieved 2026-06-27
- CreationPolicy attribute: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-attribute-creationpolicy.html — retrieved 2026-06-27
- cfn-signal: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/cfn-signal.html — retrieved 2026-06-27
- cfn-helper-scripts: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-helper-scripts-reference.html — retrieved 2026-06-27
- General template snippets (Fn::Base64 UserData): https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/quickref-general.html — retrieved 2026-06-27
- Delete a CloudFormation stack: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-delete-stack.html — retrieved 2026-06-27
- DeletionPolicy attribute: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-attribute-deletionpolicy.html — retrieved 2026-06-27
- EC2 instance console output: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-console.html — retrieved 2026-06-27
- EC2 pricing (us-east-1, Linux, on-demand) — AWS pricing page requires JavaScript; values cross-checked via cloudprice.net and holori.com against the AWS Pricing API — retrieved 2026-06-27
