<template>
  <div class="home">
    <!--<img alt="Vue logo" src="../assets/logo.png">--->
        <h3>Create certificate for requester</h3>
            <el-row>
              <el-col :span="22">
                <el-form
                :model="createCert"
                :rules="rules"
                ref="createCert"
                label-width="160px"
              >
                <el-col :span="10">
                  <el-form-item label="Product ID" prop="prodID">
                  <el-input v-model="createCert.prodID" placeholder="Please enter Product ID."></el-input>
                  </el-form-item>
                  <el-form-item label="Product description" prop="productDescription">
                    <el-input v-model="createCert.productDescription" placeholder="Please enter product description."></el-input>
                  </el-form-item>
                  <el-form-item label="IPFS hash" prop="IPFS_Hash">
                    <el-input v-model="createCert.IPFS_Hash" placeholder="Please enter product IPFS hash."></el-input>
                  </el-form-item>
                  <el-form-item label="Origin of product" prop="Origin">
                      <el-input v-model="createCert.Origin" placeholder="Please enter product origin."></el-input>
                    </el-form-item>
                  </el-col>

                  <el-col :span="10" :offset="2">
                    <el-form-item label="Requester's signature" prop="farmerSig">
                    <el-input v-model="createCert.farmerSig" placeholder="Please enter signature of requester."></el-input>
                    </el-form-item>
                    <el-form-item label="Address of requester" prop="public_blockchainAddress">
                      <el-input v-model="createCert.public_blockchainAddress" placeholder="Please enter address of requester."></el-input>
                    </el-form-item>
                    <el-form-item label="Cert status" prop="certStatus">
                      <el-select
                        v-model="createCert.certStatus"
                        style="width:100%"
                        placeholder="Select cert status">
                        <el-option label="Approved" value="1"></el-option>
                        <el-option label="Denied" value="0"></el-option>
                      </el-select>
                    </el-form-item>
                  </el-col>

                  <el-col :span="15" :offset="2">
                    <el-form-item label="**Validators's consent**" prop="authCheckBox">
                      <el-checkbox v-model="createCert.authCheckBox">I understand the implication of this action.</el-checkbox>
                    </el-form-item>
                  </el-col>
              </el-form>
              </el-col>
            </el-row>
            <el-row>
              <el-button :loading="certCreateLoadBtn" @click="processFormData('createCert')" type="primary" plain>Create Certificate</el-button>
                <el-button @click="resetForm('createCert')">Reset</el-button>
              </el-row>
            <br>
            <br>
            <el-row>
              <el-col :span="22">
                    <fieldset>
                        <legend>Processed data</legend>
                            <el-row>
                                <el-col :span="5" :offset="0">
                                    <p class="computedLabels">ProdDetailsHash:</p>
                                </el-col>
                                <el-col :span="5" :offset="0">
                                    <p class="formattedString_larger">{{prodDetailsHash}}</p>
                                </el-col>
                            </el-row>
                            <el-row>
                              <el-col :span="5">
                                <p class="computedLabels">Validator's sign.:</p>
                                </el-col>
                                <el-col :span="16">
                                    <p class="formattedString">{{valSignature}}</p>
                                </el-col>
                            </el-row>
                            <el-row>
                              <el-col :span="5">
                                <p class="computedLabels">IPFS hash of uploaded cert.:</p>
                                </el-col>
                                <el-col :span="10">
                                    <p class="formattedString_larger">{{IPFSHashOfUploadedCert}}</p>
                                </el-col>
                            </el-row>
                    </fieldset>
                </el-col>
            </el-row>
  </div>
</template>

<script>
// @ is an alias to /src
// import HelloWorld from '@/components/HelloWorld.vue'
import ethEnabled from '@/assets/js/web3nMetaMask'
import * as signatureGenerator from '@/assets/js/signatureHelperFunc'
import getHash from '@/assets/js/hashFunc'
const ipfs = new window.Ipfs()

export default {
  data () {
    return {
      createCert: {
        prodID: '',
        productDescription: '',
        IPFS_Hash: '',
        Origin: '',
        farmerSig: '',
        public_blockchainAddress: '',
        certStatus: '',
        authCheckBox: false
      },
      // Dynamic variables.
      prodDetailsHash: '',
      valSignature: '',
      addrOfValidator: '',
      IPFSHashOfUploadedCert: '',
      // Loading states
      loadingCertCreationgPage: true,
      certCreateLoadBtn: false,
      prodData: null,
      rules: {
        prodID: [
          { required: true, message: 'Please input product ID', trigger: 'blur' },
          { min: 6, message: 'Length should be at least 6', trigger: 'blur' }
        ],
        productDescription: [
          { required: true, message: 'Please input product description', trigger: 'blur' },
          { min: 5, message: 'Length should be at least 5', trigger: 'blur' }
        ],
        IPFS_Hash: [
          { required: true, message: 'Please input IPFS hash of product', trigger: 'blur' },
          { min: 5, message: 'Length should be at least 5', trigger: 'blur' }
        ],
        Origin: [
          { required: true, message: 'Please input origin of product', trigger: 'blur' },
          { min: 5, message: 'Length should be at least 5', trigger: 'blur' }
        ],
        farmerSig: [
          { required: true, message: 'Please input signature of requester', trigger: 'blur' },
          { min: 5, message: 'Length should be at least 5', trigger: 'blur' }
        ],
        public_blockchainAddress: [
          { required: true, message: 'Please input address of requester', trigger: 'blur' },
          { min: 5, message: 'Length should be at least 5', trigger: 'blur' }
        ],
        certStatus: [
          { required: true, message: 'Please select cert status from the list.', trigger: 'blur' }
        ]
      }
    }
  },
  created () {
    if (!ethEnabled()) {
      this.$message('Please install an Ethereum-compatible browser or extension like MetaMask to use this dApp!')
    } else {
      this.loadingCertCreationgPage = false
      this.getAccount().then(accounts => {
        this.addrOfValidator = accounts[0]
        console.log('Address of validator: ', this.addrOfValidator)
      })
    }
  },
  methods: {
    async getAccount () {
      var accounts = await window.ethereum.request({ method: 'eth_requestAccounts' })
      return accounts
    },
    processFormData (formName) {
      console.log('Cert generation has begun')
      if (this.createCert.authCheckBox === true) {
        this.$refs[formName].validate(valid => {
          this.certCreateLoadBtn = true
          if (valid) {
            this.prodData = {
              prodID: this.createCert.prodID,
              prodDesc: this.createCert.productDescription,
              IPFS_Hash: this.createCert.IPFS_Hash,
              Origin: this.createCert.Origin,
              requesterSig: this.createCert.farmerSig,
              public_blockchainAddress: this.createCert.public_blockchainAddress,
              certStatus: this.createCert.certStatus,
              certCreationTime: Math.round(+new Date() / 1000)// unix timestamp
            }
            // Validation completed. Proceed with main logic.
            // Concat product details and hash.
            var prepData = this.prodData.prodID + this.prodData.prodDesc + this.prodData.IPFS_Hash + this.prodData.Origin +
            this.prodData.farmerSig + this.prodData.public_blockchainAddress + this.prodData.certStatus + this.prodData.certCreationTime
            getHash(prepData).then(res => {
              this.prodDetailsHash = res
              // Validator signs prodDetailsHash to get signature. --->valSignature
              this.getSignatureFromValidator()
            })
          } else {
            console.log('Submission error.')
            this.certCreateLoadBtn = false
            return false
          }
          console.log('Product details: ', this.prodData)
        })
      } else {
        this.$message('Please check the checkbox')
      }
    },
    resetForm (formName) {
      this.$refs[formName].resetFields()
    },
    getSignatureFromValidator () {
      // eslint-disable-next-line no-return-assign
      signatureGenerator.signatureGen(this.prodDetailsHash, this.addrOfValidator, (sig) => {
        this.valSignature = sig.replace(/"/g, '') // Remove the double quotes.
        console.log('Signature of validator: ', this.valSignature)
        this.sendCertToIPFShub()
      })
    },
    sendCertToIPFShub () {
      // Add validator's signature and hash to the data to be sent to IPFS.
      this.prodData.valSignature = this.valSignature
      this.prodData.prodDetailsHash = this.prodDetailsHash
      var certDataToSendToIPFS = JSON.stringify(this.prodData)
      // console.log('Connecting to IPFS.')
      const MyBuffer = window.Ipfs.Buffer
      var dataToBuffer = MyBuffer.from(certDataToSendToIPFS)
      // console.log('Buffer conversion done.')
      ipfs.add(dataToBuffer).then(res => {
        console.log('Data upload to IPFS sucessful')
        this.$message({
          message: 'Certificate upload to IPFS successful.',
          type: 'success'
        })
        this.IPFSHashOfUploadedCert = res[0].hash
        this.certCreateLoadBtn = false
      }).catch(err => {
        console.log('Error adding file to IPFS storage hub.', err)
        this.$message.error('Oops, Error adding certificate to IPFS')
      })
    }
  }
}
</script>
<style scoped>
.home {
  background-color: #ffffff;
  border-radius: 4px;
  margin: 0.1% auto;
  width: 75%;
  padding: 1rem 1.5rem;
}
fieldset {
  border-radius: 2rem;
}

legend {
 font-style: italic;
}
.computedLabels{
  text-align: left;
  font-size: 0.72rem;
  color: rgb(113, 140, 189);
}
.formattedString_larger {
  font-size: 0.74rem;
  font-style: italic;
  color: rgb(95, 64, 116);
  text-align: left;
}
.formattedString{
  font-size: 0.65rem;
  font-style: italic;
  color: rgb(95, 64, 116);
  text-align: left;
}
</style>
