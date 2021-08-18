const https = require("https");
const util = require("util");
const fs = require('fs');
const exec = util.promisify(require("child_process").exec);

const options = {
  key: fs.readFileSync('/app/https.key'),
  cert: fs.readFileSync('/app/https.crt')
};

const execCmd = async (cmd) => {
  try{
    exec_res = await exec(cmd);
    if (exec_res.error == null) {
      return 0 
    } else {
      console.log(exec_res.error);
      return -1
    }
  } catch (er){
    console.log(er);
    return -1
  }
}


const server = https.createServer(options, async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*")
  
  
  if (req.url.startsWith("/dms-renew/") && req.method === "POST") {
    console.log(req.url);
    const deviceId = req.url.split("/dms-renew/")[1]
    console.log(deviceId);
    const aps = "Lamassu-Root-CA2-RSA2048"
    const CMD_ENROLL = 'estclient reenroll -server dev.lamassu.io:9998 -explicit /app/device-manager-anchor.crt -csr /app/devices-crypto-material/device-'+deviceId+'.csr -out /app/devices-crypto-material/device-reenrolled-'+deviceId+'.crt -aps ' + aps + ' -certs /app/devices-crypto-material/device-'+deviceId+'.crt -key /app/devices-crypto-material/device-'+deviceId+'.key' ;
    if (await execCmd(CMD_ENROLL) == 0) {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ message: "Executed correctly" }));
    } else {
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ message: "Internal server error" }));
    }

  } else if (req.url.startsWith("/dms-issue/csr/") && req.method === "POST") {
    const cn_aps = req.url.split("/dms-issue/csr/")[1]
    const cn=cn_aps.split("/")[0]
    const aps=cn_aps.split("/")[1]

    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', async () => {
      const data = Buffer.concat(chunks).toString("utf-8");

      fs.writeFileSync('/app/devices-crypto-material/device-'+cn+'.csr', data)
      const CMD_ENROLL = 'estclient enroll -server dev.lamassu.io:9998 -explicit /app/device-manager-anchor.crt -csr /app/devices-crypto-material/device-'+cn+'.csr -out /app/devices-crypto-material/device-'+cn+'.crt -aps ' + aps + ' -certs /app/enrolled-dms.crt -key /app/enrolled-dms.key' ;
      console.log(CMD_ENROLL);
      if (await execCmd(CMD_ENROLL) == 0) {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ message: "Executed correctly" }));
      } else {
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ message: "Internal server error" }));
      }
    })
    
  } else if (req.url.startsWith("/dms-issue/") && req.method === "POST") {
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', async () => {
      const data = JSON.parse(Buffer.concat(chunks).toString("utf-8"));

      const cn_aps = req.url.split("/dms-issue/")[1]
      const cn=cn_aps.split("/")[0]
      const aps=cn_aps.split("/")[1]

      const c = data.c ? data.c : ""
      const st = data.st ? data.st : ""
      const l = data.l ? data.l : ""
      const o = data.o ? data.o : ""
      const ou = data.ou ? data.ou : ""

      var CMD_GEN_CSR
      if (data.key_type == "ec") {
        CMD_GEN_CSR = 'openssl req -nodes -newkey ec -pkeyopt ec_paramgen_curve:secp' + data.key_bits +'r1  -keyout /app/devices-crypto-material/device-'+cn+'.key -out /app/devices-crypto-material/device-'+cn+'.csr -subj "/C=' + c +'/ST=' + st +'/L=' + l +'/O=' + o +'/OU=' + ou +'/CN='+cn+'"'
      }else{
        // CMD_GEN_CSR = 'openssl req -nodes -newkey rsa:' + data.key_bits +' -keyout /app/devices-crypto-material/device-'+cn+'.key -out /app/devices-crypto-material/device-'+cn+'.csr -subj "/C=' + c +'/ST=' + st +'/L=' + l +'/O=' + o +'/OU=' + ou +'/CN='+cn+'"'
        CMD_GEN_CSR = 'openssl req -nodes -newkey rsa:' + data.key_bits +' -keyout /app/devices-crypto-material/device-'+cn+'.key -out /app/devices-crypto-material/device-'+cn+'.csr -subj "/CN='+cn+'"'
      }

      console.log(CMD_GEN_CSR);
      
      if (await execCmd(CMD_GEN_CSR) == -1) {
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ message: "Executed correctly" }));
      }else{
        const CMD_ENROLL = 'estclient enroll -server dev.lamassu.io:9998 -explicit /app/device-manager-anchor.crt -csr /app/devices-crypto-material/device-'+cn+'.csr -out /app/devices-crypto-material/device-'+cn+'.crt -aps ' + aps + ' -certs /app/enrolled-dms.crt -key /app/enrolled-dms.key' ;
        console.log(CMD_ENROLL);
        if (await execCmd(CMD_ENROLL) == 0) {
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ message: "Executed correctly" }));
        } else {
          res.writeHead(500, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ message: "Internal server error" }));
        }
      }
    })


  } else {
    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ message: "Route not found" }));
  }
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`Server running on port ${PORT}`));
