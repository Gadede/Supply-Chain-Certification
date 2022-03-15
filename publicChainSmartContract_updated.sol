// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.17;
import "github.com/provable-things/ethereum-api/blob/master/provableAPI_0.5.sol"; // Provable service.
import "github.com/chrisdotn/jsmnSol/blob/master/contracts/JsmnSolLib.sol"; // To work with JSON returned from Provable service.

contract supplychain is usingProvable{
    // IPFS Hash sample: QmWNWLzEAt3Bik6m8GKc1p8zJGc5LGtNDFavSgsAJVRZfn
    
    string[] cert_Hashes; 
    address[] validators; //hold public addresses of validators in the private chain
    address admin;
    string certRetrievedFromIPFS; // Variable to hold the cert to be retrieved by Provable from IPFS.
    //struct to capture farmer product details 
    struct farmerInput {
            string productDetails;
            string Quantity;
            uint256 Price;
            string Origin;
            address farmerAddress;
            string productID;
            address payable partnerAddress;
        }
    struct productIDnPrRel {
        string productID;
        uint256 Price;
        address partnerAddress;
    }
    
    // relationship between manufacturer and wholesellers
    struct partnerMaps {
        string  productID;
        address payable wholeseller;
        uint256 Price;
        
    }
    
    // struct binding wholesellers to retailers
     struct wholeseller_RetailerMap {
        string  productID;
        address retailer; 
        uint256 Price;
        
    }
    // Events begin.
    event faillog(string msg); 
    event shippingAlert (address farmerAddress, string shippingAddress);
    event payFarmer (string msg); 
    event payManufacturer(string msg); 
    event payWholeseller(string msg);
    event certReceived(string msg, string cert);
    event message(string msg);
    // Events end.
 
    
    mapping(string => partnerMaps) internal manufacturer_wholeseller_Relationship; //mapping for manufacturer and wholesellers
    
    mapping(string => wholeseller_RetailerMap) internal wholeseller_Retailer_Relationship; //mapping for wholesellers and retailers
    
    mapping(string => farmerInput) internal f_input; //mapping to hold farmer input
    
    mapping(string => productIDnPrRel) internal prodIDnPriceMap;
    
    constructor () internal {
           validators[0]= 0x50942a4cf3D43854bE8ce2025361d8571b05B05A;
           validators[1]= 0x9F71Ac7e084EFf09c3cc8B316Bc152A86f3283Be;
           admin = msg.sender;
           provable_setProof(proofType_Ledger);
       }
    
    function farmer_product_data(string memory productDetails, string memory Quantity, uint256 Price, string memory Origin, string memory cert_IPFS_Hash, string memory productID, address payable partnerAddress) public  returns(bool){
         require(bytes(cert_IPFS_Hash).length == 46);
         uint8 verifyResults = verifyInclusiveness(cert_IPFS_Hash, cert_Hashes);
         if(verifyResults == 0){
            getCertificateFromIPFSviaProvable(cert_IPFS_Hash);
            // certRetrievedFromIPFS now contains the returned json cert as a string. Parse it using json parser library.
            // Needed variables for json prser begins.
            uint returnValue;
            JsmnSolLib.Token[] memory tokens;
            uint actualNum;
             // Needed variables for josn parser ends.
             // Parse the json string.
             (returnValue, tokens, actualNum) = JsmnSolLib.parse(certRetrievedFromIPFS, 21);
             // Check if parsing was successful. 0 for success and non-zero for error.
             if (returnValue==0){
                 // Extract needed parts of the parsed json now stored in "tokens begins.
                JsmnSolLib.Token memory pID = tokens[2]; // prodID
                JsmnSolLib.Token memory reqAddr = tokens[12]; // farmerPubAddress of cert requester.
                JsmnSolLib.Token memory cStatus = tokens[14]; // certStatus
                JsmnSolLib.Token memory valSig = tokens[18]; // signature of validator within the cert.
                JsmnSolLib.Token memory prodHash = tokens[20]; // prodDetailsHash inside the cert. No need since signature is used.
                
                // Extract substrings by converting to bytes. This is same as getting productID, cert status, signature and hash from the parsed json.
                string memory prodID = JsmnSolLib.getBytes(certRetrievedFromIPFS, pID.start, pID.end);
                string memory reqAddress = JsmnSolLib.getBytes(certRetrievedFromIPFS, reqAddr.start, reqAddr.end);
                string memory certState = JsmnSolLib.getBytes(certRetrievedFromIPFS, cStatus.start, cStatus.end);
                string memory valSignature = JsmnSolLib.getBytes(certRetrievedFromIPFS, valSig.start, valSig.end);
                string memory productHash = JsmnSolLib.getBytes(certRetrievedFromIPFS, prodHash.start, prodHash.end);
                
                // Perform needed type conversions.
                int Cert_Status = JsmnSolLib.parseInt(certState); // Certstatus to uint. 
                bytes32 prodDetailsHash = convStringToBytes32(productHash);
                bytes memory signature = bytes(valSignature);
                address farmerPubAddress = parseAddr(reqAddress); // This is helper function available in Provable.
                
                // Perform validation checks.
                // check msg.sender matches farmer public address
                require(msg.sender == farmerPubAddress, "Requester public address mismatch");
             
                //require that cert status is approved
                require(Cert_Status == 1, " Cert status is Not Approved");
                 
                //check productID matches productID input parameter
                require(keccak256(abi.encodePacked(prodID)) == keccak256(abi.encodePacked(productID)), "Product ID mismatch");
                 
                // recover validator address from signature & check inclusiveness in validators array
                require(verifyValidator(getValidator(prodDetailsHash, signature), validators) == 1);
                 
                cert_Hashes.push(cert_IPFS_Hash);
                f_input[productID] = farmerInput(productDetails, Quantity,Price,Origin, msg.sender, productID, partnerAddress);
                prodIDnPriceMap[productID] = productIDnPrRel(productID, Price, partnerAddress);
                return true;
             }
             else {
                 emit faillog("Sorry! Could not parse JSON returned by IPFS via Provable");
                 return false;
             }
         }
         else {
             emit faillog("IPFS Hash already exist");
             return false;
         }
        
    }
    //function to check if IPFS_Hash inputed already exist in the contract
    function verifyInclusiveness(string memory IPFS_Hash, string[] memory certHashes) internal pure returns (uint8){
        for(uint256 i = 0; i < certHashes.length; i++){ 
            if ((keccak256(abi.encodePacked((certHashes[i]))) == keccak256(abi.encodePacked(((IPFS_Hash)))))){ 
            // keccak256(abi.encodePacked converts the cert hash to byte before comparing it             
              return 1;
            }
         }      
        return 0;
        }
        // verify validator address is part of the validators array
         function verifyValidator(address signer, address[] memory validatorsArray) internal pure returns (uint8){
        for(uint256 i = 0; i < validatorsArray.length; i++){ 
            if (validatorsArray[i] == signer){ 
              return 1; // validator is included
            }
         }      
        return 0; // validator not included
    }
    
    function Buy_Farmer_Product(address payable farmer_Address, string memory productID, string memory shippingAddress, address payable wholeseller) public payable returns(string memory){
            require(prodIDnPriceMap[productID].Price == msg.value, "Price mismatch");// require product ID price is same as value sent
            require(msg.sender == prodIDnPriceMap[productID].partnerAddress); //require partner address stated by farmer is the address calling this function
            farmer_Address.transfer(msg.value);
            emit payFarmer(" Farmer Payment Successful");
            manufacturer_wholeseller_Relationship[productID].productID = productID;
            manufacturer_wholeseller_Relationship[productID].wholeseller = wholeseller;
            emit shippingAlert (farmer_Address, shippingAddress);
            return "Transaction Successful";
            
    }
    
    function setWholesalePrice(string memory productID, uint256 Price) public payable returns(bool){
      require (f_input[productID].partnerAddress == msg.sender);
      manufacturer_wholeseller_Relationship[productID].Price = Price;
      return true;
    }
        
    function assetTransfer_wholseller(string memory productID, address retailer) public payable returns(bool){
        require( manufacturer_wholeseller_Relationship[productID].wholeseller == msg.sender);
        require(manufacturer_wholeseller_Relationship[productID].Price == msg.value, "Price mismatch");
        f_input[productID].partnerAddress.transfer(msg.value);
        emit payManufacturer(" manufacturer Payment Successful");
        
        wholeseller_Retailer_Relationship[productID].retailer = retailer;
        return true;
    }
    
    function setRetailPrice(string memory productID, uint256 Price) public payable returns(bool){
      require (manufacturer_wholeseller_Relationship[productID].wholeseller == msg.sender);
      wholeseller_Retailer_Relationship[productID].Price = Price;
      return true;
    }
    
    function assetTransfer_retailer(string memory productID) public payable returns(bool){
        require( wholeseller_Retailer_Relationship[productID].retailer == msg.sender);
        require(wholeseller_Retailer_Relationship[productID].Price == msg.value, "Price mismatch");
        manufacturer_wholeseller_Relationship[productID].wholeseller.transfer(msg.value);
        emit payWholeseller(" wholeseller Payment Successful");
        return true;
    }
    
    function recoverSigner(bytes32 h, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, h));
        address addr = ecrecover(prefixedHash, v, r, s);
        return addr;
    }
    
    function getValidator(bytes32 hash, bytes memory sig) internal pure returns (address) {
        require(sig.length == 65, "Require correct length");
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Divide the signature in r, s and v variables
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28, "Signature version not match");

        return recoverSigner(hash, v, r, s);
    }
    
    function convStringToBytes32(string memory source) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(source, 32))
            }
    }

    //how to generate a unique product ID  for each farmer Input..(remember to search)
    
    // Follwing functions are dependent on Provable.
    function getCertificateFromIPFSviaProvable(string memory cert_IPFS_Hash) public payable {
        emit message("Provable query to get Cert on IPFS sent, waiting for the answer...");
        provable_query("IPFS", cert_IPFS_Hash); // Send query to Provable to get the cert stored on IPFS.
    } 
    
    function __callback(bytes32 myid, string memory result, bytes memory proof) public {
       if (msg.sender != provable_cbAddress()) revert();
       if(provable_randomDS_proofVerify__returnCode(myid, result, proof) == 0){
            certRetrievedFromIPFS = result; // Assign the cert retireved by Provable from IPFS to certRetrievedFromIPFS
            emit certReceived("Cert received from IPFS", result); // Emit event.
        }
        else{
            // Handle failed proof verification.
            emit message("Failed Provable verification.");
        }
   }
}