const https = require("https");
const util = require("util");
const fs = require('fs');
const exec = util.promisify(require("child_process").exec);

const options = {
  key: fs.readFileSync('/app/https.key'),
  cert: fs.readFileSync('/app/https.crt')
};


const server = https.createServer(options, async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*")

  if (req.url.startsWith("/dms-renew/") && req.method === "POST") {
      const deviceId = req.url.split("/dms-issue/")[1]
  } else if (req.url.startsWith("/dms-issue/") && req.method === "POST") {
    const cn_aps = req.url.split("/dms-issue/")[1]
    const cn=cn_aps.split("/")[0]
    const aps=cn_aps.split("/")[1]

    const CMD_GEN_CSR = 'openssl req -nodes -newkey rsa:2048 -keyout /app/devices-crypto-material/device-'+cn+'.key -out /app/devices-crypto-material/device-'+cn+'.csr -subj "/C=ES/ST=Gipuzkoa/L=Arrasate/O=Ikerlan/OU=ZPD/CN='+cn+'"'
    const CMD_ENROLL = 'estclient enroll -server lamassu.zpd.ikerlan.es:9998 -explicit /app/device-manager-anchore.crt -csr /app/devices-crypto-material/device-'+cn+'.csr -out /app/devices-crypto-material/device-'+cn+'.crt -aps ' + aps + ' -certs /app/enrolled-dms.crt -key /app/enrolled-dms.key' ;

    console.log(CMD_GEN_CSR);
    console.log(CMD_ENROLL);

    var exec_res = await exec(CMD_GEN_CSR);
    
    if (exec_res.error != null) {
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ message: "Executed correctly" }));
    }else{
      exec_res = await exec(CMD_ENROLL);
      if (exec_res.error == null) {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ message: "Executed correctly" }));
      } else {
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ message: "Internal server error" }));
      }
    }


  } else {
    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ message: "Route not found" }));
  }
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`Server running on port ${PORT}`));
