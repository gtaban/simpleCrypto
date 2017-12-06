//
//  evp_rsa.swift
//  simpleRSAPackageDescription
//
//  Created by Gelareh Taban on 11/29/17.
//

import Foundation
import OpenSSL


extension myRSA {
    
    // EVP_PKEY = general private key without reference to any particular algorithm
    static var rsaKeypair: UnsafeMutablePointer<EVP_PKEY>? = nil

    static var rsaEncryptCtx: UnsafeMutablePointer<EVP_CIPHER_CTX>? = nil
    static var rsaDecryptCtx: UnsafeMutablePointer<EVP_CIPHER_CTX>? = nil

    typealias UInt8Ptr = UnsafeMutablePointer<UInt8>?

    public func generateRSAKey() -> Bool {
        
        // Init RSA key
        let ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, nil);
        
        if (EVP_PKEY_keygen_init(ctx) <= 0 ) {
            print("FAILURE at EVP_PKEY_keygen_init")
            return false
        }
        
        // EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, RSA_KEY_LENGTH) is a complex macros and
        // therefore the compiler doesnt convert it directly to swift.
        // from /usr/local/opt/openssl/include/openssl/rsa.h
        // # define EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, bits) EVP_PKEY_CTX_ctrl(ctx, EVP_PKEY_RSA, EVP_PKEY_OP_KEYGEN, EVP_PKEY_CTRL_RSA_KEYGEN_BITS, bits, NULL)

        if (EVP_PKEY_CTX_ctrl(ctx, EVP_PKEY_RSA, EVP_PKEY_OP_KEYGEN, EVP_PKEY_CTRL_RSA_KEYGEN_BITS, RSA_KEY_LENGTH, nil) <= 0) {
            print("FAILURE at EVP_PKEY_CTX_set_rsa_keygen_bits")
            return false
        }
        
        if(EVP_PKEY_keygen(ctx, &myRSA.rsaKeypair) <= 0) {
            print("FAILURE at EVP_PKEY_keygen")
            return false
        }
        EVP_PKEY_CTX_free(ctx);
        return true
    }
    
    public func evpRSADeinit() {
        
        let EVP_CIPHER_CTX_LENGTH = MemoryLayout<EVP_CIPHER_CTX>.size

        myRSA.rsaEncryptCtx?.deallocate(capacity: EVP_CIPHER_CTX_LENGTH)
        myRSA.rsaDecryptCtx?.deallocate(capacity: EVP_CIPHER_CTX_LENGTH)
    }

    // Creates the AES key and IV
    public func evpRSAInit() -> Bool {
        
        // Initalize contexts
        let EVP_CIPHER_CTX_LENGTH = MemoryLayout<EVP_CIPHER_CTX>.size
        
        // rsaEncryptCtx = (EVP_CIPHER_CTX*)malloc(sizeof(EVP_CIPHER_CTX));
        myRSA.rsaEncryptCtx = UnsafeMutablePointer<EVP_CIPHER_CTX>.allocate(capacity: EVP_CIPHER_CTX_LENGTH)
        myRSA.rsaDecryptCtx = UnsafeMutablePointer<EVP_CIPHER_CTX>.allocate(capacity: EVP_CIPHER_CTX_LENGTH)
        
        EVP_CIPHER_CTX_init(myRSA.rsaEncryptCtx);
        EVP_CIPHER_CTX_init(myRSA.rsaDecryptCtx);
        
        return true
    }
    
    
    // Uses aes_256_cbc for envelope
    // Takes in a plaintext, then generates an AES key and IV for aes_256_cbc encryption of the plaintext
    // encrypts the key using the RSA key context has been initialized with.
    public func rsaEncrypt(plaintext: String)
                                                                    // Output:
                               -> ( UnsafeMutablePointer<UInt8>? ,  // ciphertext
                                    Int32,                          // ciphertextLength
                                    UnsafeMutablePointer<UInt8>? ,  // encKey
                                    Int32,                          // encKeyLength
                                    UnsafeMutablePointer<UInt8>? ,  // IV
                                    Int32 ) {                       // IVLength

        var processedLength: Int32 = 0
        var cipherLength: Int32 = 0
        let pubKeyCount = 1   // using only 1 public key pair
        // All Seal*() return 0 on error or npubk if successful

        // unsigned char **ek
        // ek is an array of buffers where the public key encrypted secret key will be written,
        // each buffer must contain enough room for the corresponding encrypted key:
        // that is ek[i] must have room for EVP_PKEY_size(pubk[i]) bytes.
        // Here we are only using 1 public key, so ek[] has only 1 entry
        // In Swift, to do (unsigned char **ek), we have to do a little typealias'ing trick and
        // create a new pointer that point to the original pointer
        var ek: UInt8Ptr
        ek = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(EVP_PKEY_size(myRSA.rsaKeypair)))
        let ekPtr = UnsafeMutablePointer<UInt8Ptr>.allocate(capacity: MemoryLayout<UInt8Ptr>.size)
        ekPtr.pointee = ek
        
        // assign size of the corresponding cipher's IV
        let IVLength = EVP_CIPHER_iv_length(EVP_aes_256_cbc()) // EVP_MAX_IV_LENGTH
        let iv = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(IVLength))
        
        let enc = UnsafeMutablePointer<UInt8>.allocate(capacity: plaintext.count + Int(IVLength))
        var encKeyLength: Int32 = 0

        // initializes a cipher context ctx for encryption with cipher type using a random secret key and IV.
        // The secret key is encrypted using the public key (can be a set of public keys)
        // Here we are using just 1 public key
                                        var status = EVP_SealInit(myRSA.rsaEncryptCtx, EVP_aes_256_cbc(), ekPtr, &encKeyLength, iv, &myRSA.rsaKeypair, 1)
        // SealInit should return the number of public keys that were input, here it is only 1
        guard status == pubKeyCount else {
            print("FAILURE at EVP_SealInit")
            return (nil, 0, nil, 0, nil, 0)
        }

        //  int EVP_SealUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl, unsigned char *in, int inl);
        // EVP_SealUpdate is a complex macros and therefore the compiler doesnt
        // convert it directly to swift. From /usr/local/opt/openssl/include/openssl/evp.h:
        // # define EVP_SealUpdate(a,b,c,d,e)       EVP_EncryptUpdate(a,b,c,d,e)
        status = EVP_EncryptUpdate(myRSA.rsaEncryptCtx, enc, &processedLength, plaintext, Int32(plaintext.count))
        guard status == pubKeyCount else {
            print("FAILURE at EVP_SealInit")
            return (nil, 0, nil, 0, nil, 0)
        }
        cipherLength = processedLength

        status = EVP_SealFinal(myRSA.rsaEncryptCtx, enc.advanced(by: Int(cipherLength)), &processedLength)
        guard status == pubKeyCount else {
            print("FAILURE at EVP_SealInit")
            return (nil, 0, nil, 0, nil, 0)
        }
        cipherLength = cipherLength + processedLength
        let ekLength = encKeyLength

        let encrypted_str = String(cString: UnsafePointer(enc))
        print("Ciphertext (\(cipherLength))= \(encrypted_str)")

        EVP_CIPHER_CTX_cleanup(myRSA.rsaEncryptCtx);
        
        return (enc, cipherLength, ek, ekLength, iv, IVLength)
    }
    
    public func rsaDecryption(ciphertext: UnsafeMutablePointer<UInt8> ,
                                  cipherLength: Int32,
                                  encKey: UnsafeMutablePointer<UInt8> ,
                                  encKeyLength: Int32,
                                  IV: UnsafeMutablePointer<UInt8> ,
                                  IVLength: Int32 )
                                                                            // Output:
                                        -> ( UnsafeMutablePointer<UInt8>?,  // decMsg
                                             Int32) {                       // decMsgLen
        
        // This is the number of bytes that each EVP_DecryptUpdate/EVP_DecryptFinal decrypts.
        // The sum of processedLen is the total size of the decrypted message (decMsgLen)
        var processedLen: Int32 = 0
        var decMsgLen: Int32 = 0
        
        let decrypted = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(cipherLength + IVLength))
        decrypted.initialize(to: 0, count: Int(cipherLength + IVLength))
        
        // EVP_OpenInit returns 0 on error or a non zero integer (actually the recovered secret key size) if successful
        var status = EVP_OpenInit(myRSA.rsaDecryptCtx, EVP_aes_256_cbc(), encKey, encKeyLength, IV, myRSA.rsaKeypair)
        guard status != EVP_CIPHER_key_length(EVP_aes_256_cbc()) else {
            print("FAILURE at EVP_OpenInit")
            return (nil, 0)
        }

        // EVP_OpenUpdate is a complex macros and therefore the compiler doesnt
        // convert it directly to swift. From /usr/local/opt/openssl/include/openssl/evp.h:
        // # define EVP_OpenUpdate(a,b,c,d,e)       EVP_DecryptUpdate(a,b,c,d,e)
        status = EVP_DecryptUpdate(myRSA.rsaDecryptCtx, decrypted, &processedLen, ciphertext, cipherLength)
        guard status != 0 else {
            print("FAILURE at EVP_DecryptUpdate")
            return (nil, 0)
        }
        
        decMsgLen = processedLen;
        
        status = EVP_OpenFinal(myRSA.rsaDecryptCtx, decrypted.advanced(by: Int(decMsgLen)), &processedLen)
        guard status != 0 else {
            print("FAILURE at EVP_OpenFinal")
            return (nil, 0)
        }
        decMsgLen = decMsgLen + processedLen

        let decrypted_str = String(cString: UnsafePointer(decrypted))
        print("DECRYPTED (\(decMsgLen))= \(decrypted_str.data(using: .utf8)?.hexEncodedString() ?? "NULL")")
        
        EVP_CIPHER_CTX_cleanup(myRSA.rsaDecryptCtx);
        return ( decrypted, decMsgLen)
    }
    
}
