const crypto = require('crypto');

const algorithm = 'aes-256-cbc';
const encrypt = (privateKey, secretKey) => {
    const hash = crypto.createHmac('sha256', secretKey)
        .digest('hex');

    // generate 16 bytes of random data
    const initVector = Buffer.from(hash).slice(0, 16);

    // secret key generate 32 bytes of random data
    const securityKey = Buffer.from(hash).slice(16, 48);

    // the cipher function
    const cipher = crypto.createCipheriv(algorithm, securityKey, initVector);

    // encrypt the message
    // input encoding
    // output encoding
    let encryptedData = cipher.update(privateKey, 'utf-8', 'hex');

    encryptedData += cipher.final('hex');
    return encryptedData;
};

const decrypt = (encryptedPrivateKey, secretKey) => {
    const hash = crypto.createHmac('sha256', secretKey)
        .digest('hex');

    // generate 16 bytes of random data
    const initVector = Buffer.from(hash).slice(0, 16);

    // secret key generate 32 bytes of random data
    const securityKey = Buffer.from(hash).slice(16, 48);

    const decipher = crypto.createDecipheriv(algorithm, securityKey, initVector);

    let decryptedData = decipher.update(encryptedPrivateKey, 'hex', 'utf-8');

    decryptedData += decipher.final('utf8');
    return decryptedData;
};

module.exports = {
    encrypt,
    decrypt,
};
