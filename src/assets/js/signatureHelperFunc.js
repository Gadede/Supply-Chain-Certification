import Web3 from 'web3'
var ethUtil = require('ethereumjs-util')

async function signatureGen (data, accountToUse, callback) {
  var msg = ethUtil.bufferToHex(Buffer.from(data))
  var from = accountToUse
  console.log('Sending personal sign request to MetaMask')
  var params = [msg, from]
  var method = 'personal_sign'
  window.web3 = new Web3(window.ethereum)
  window.web3.currentProvider.sendAsync({
    method,
    params,
    from
  }, function (err, result) {
    if (err) return console.log('Signature error: ', err)
    if (result.error) return console.log('Sorry! Error with signature result: ', result.error)
    // console.log('PERSONAL SIGNED:' + JSON.stringify(result.result))
    callback(JSON.stringify(result.result))
  })
}

signatureGen('data', 'accountToUse', function (sig) {
  console.log('Signature: ', sig)
})

export { signatureGen }
