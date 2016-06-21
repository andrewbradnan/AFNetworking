//
//  SFNetworkingTests.swift
//  SFNetworkingTests
//
//  Created by Andrew Bradnan on 6/20/16.
//  Copyright © 2016 AFNetworking. All rights reserved.
//

import XCTest
import SFNetworking
import FutureKit

class SFNetworkingTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        self.manager = SFHTTPSessionManager<Void>(baseURL: self.baseURL, converter: {_ in })
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        self.manager.invalidateSessionCancelingTasks(true)

        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
 
    let baseURL = NSURL(string:"http://httpbin.org/")
    var manager: SFHTTPSessionManager<Void> = SFHTTPSessionManager<Void>(baseURL: NSURL(string:"http://httpbin.org/"), converter: {_ in })
    
//    func testSharedManagerIsNotEqualToInitdManager() {
//        XCTAssertFalse(SFHTTPSessionManager.manager === self.manager)
//    }
    
    // MARK: misc
    
    /*
    func testThatOperationInvokesCompletionHandlerWithResponseObjectOnSuccess() {
        let expectation = self.expectationWithDescription("Request should succeed")
    
        if let get = NSURL(string:"/get", relativeToURL:self.baseURL) {
            let request = NSURLRequest(URL:get)
            
            let f = self.getFutureForRequest(request)

            f.onSuccess{
                expectation.fulfill()
            }
            
            self.waitForExpectationsWithTimeout(10.0, handler:nil)

            XCTAssertTrue(f.isCompleted)
        }
    }

    func getFutureForRequest(request: NSURLRequest) -> Future<Void> {
        let f = self.manager.dataTaskWithRequest(request)
        
        f.onFail(block: { _ in XCTAssert(false, "fail") })
        f.onCancel(block: { XCTAssert(false, "cancelled") })
        
        return f
    }
    */
    /*
    func testThatOperationInvokesFailureCompletionBlockWithErrorOnFailure() {
        let expectation = self.expectationWithDescription("Request should 404")
        
        if let fourofour = NSURL(string:"/status/404", relativeToURL:self.baseURL) {
            let request = NSURLRequest(URL:fourofour)
            let f = self.manager.dataTaskWithRequest(request)
        
            f.onFail(block: { (error:ErrorType) -> Void in
                if case SFError.FailedResponse(let e) = error where e == 404 {
                    expectation.fulfill()
                }
                else {
                    XCTAssert(false, "bogus error")
                }
            })
            f.onSuccess(block: { XCTAssert(false, "success unexpected") })
            f.onCancel(block: { XCTAssert(false, "cancelled") })

            self.waitForExpectationsWithTimeout(10.0, handler:nil)

            XCTAssertTrue(f.isCompleted)
        }
    }
    
    func testThatRedirectBlockIsCalledWhen302IsEncountered() {
        let expectation = self.expectationWithDescription("Request should succeed")
        
        if let redir = NSURL(string:"/redirect/1", relativeToURL:self.baseURL) {
            let redirectRequest = NSURLRequest(URL:redir)

            self.manager.taskWillPerformHTTPRedirection = { (session: NSURLSession, t: NSURLSessionTask, response: NSURLResponse, request: NSURLRequest)->NSURLRequest? in
                return request
            }
            
            let f = self.getFutureForRequest(redirectRequest)
            
            f.onSuccess(block: { expectation.fulfill() })
            
            self.waitForExpectationsWithTimeout(10.0, handler:nil)
            
            XCTAssertTrue(f.isCompleted)
        }
    }
 
    func testDownloadFileCompletionSpecifiesURLInCompletionWithManagerDidFinishBlock() {
        var managerDownloadFinishedBlockExecuted = false
        var downloadFilePath: NSURL?
        
        let expectation = self.expectationWithDescription("Request should succeed")
        
        self.manager.downloadTaskDidFinishDownloading = { (NSURLSession, NSURLSessionDownloadTask, NSURL) -> NSURL? in
            managerDownloadFinishedBlockExecuted = true
            let dirURL = NSFileManager.defaultManager().URLsForDirectory(.LibraryDirectory, inDomains:.UserDomainMask).last
        
            downloadFilePath = dirURL?.URLByAppendingPathComponent("t1.file")
            return downloadFilePath
        }
        
        let f = self.manager.downloadTaskWithRequest(NSURLRequest(URL:self.baseURL!))

        f.onSuccess{_ in 
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(10.0, handler:nil)
        
        XCTAssertTrue(f.isCompleted)
        XCTAssertTrue(managerDownloadFinishedBlockExecuted)
        XCTAssertNotNil(downloadFilePath)
    }
 
    func testDownloadFileCompletionSpecifiesURLInCompletion() {
        var downloadFilePath: NSURL?
        
        let expectation = self.expectationWithDescription("Request should succeed")
        
        let f = self.manager.downloadTaskWithRequest(NSURLRequest(URL:self.baseURL!))
        
        f.onSuccess{ url in
            downloadFilePath = url
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(10.0, handler:nil)
        
        XCTAssertTrue(f.isCompleted)
        XCTAssertNotNil(downloadFilePath)
    }
 
    func testThatSerializationErrorGeneratesErrorAndNullTaskForGET() {
        let expectation = self.expectationWithDescription("Serialization should fail")

        self.manager.requestSerializer.queryStringSerializer = { (NSURLRequest, parameters: Parameters) throws -> String in
            throw TestError.Foo
        }
        
        let f = self.manager.GET("test", parameters:["key":"value"], downloadProgress:nil)
        
        f.onFail{ e -> Void in
            expectation.fulfill()
        }

        self.waitForExpectationsWithTimeout(10.0, handler:nil)
    }


//    #pragma mark - NSCoding
//    
//    - (void)testSupportsSecureCoding {
//    XCTAssertTrue([AFHTTPSessionManager supportsSecureCoding]);
//    }
//    
//    - (void)testCanBeEncoded {
//    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.manager];
//    XCTAssertNotNil(data);
//    }
//    
//    - (void)testCanBeDecoded {
//    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.manager];
//    AFHTTPSessionManager *newManager = [NSKeyedUnarchiver unarchiveObjectWithData:data];
//    XCTAssertNotNil(newManager.securityPolicy);
//    XCTAssertNotNil(newManager.requestSerializer);
//    XCTAssertNotNil(newManager.responseSerializer);
//    XCTAssertNotNil(newManager.baseURL);
//    XCTAssertNotNil(newManager.session);
//    XCTAssertNotNil(newManager.session.configuration);
//    }
    
    // MARK: NSCopying
    
//    - (void)testCanBeCopied {
//    AFHTTPSessionManager *copyManager = [self.manager copy];
//    XCTAssertNotNil(copyManager);
//    }
    
    // MARK: Progress
    
    func testDownloadProgressIsReportedForGET() {
        let expectation = self.expectationWithDescription("Progress should equal 1.0")

        self.manager.GET("image", parameters:["Accept":"image/jpeg"], downloadProgress: { (downloadProgress: NSProgress) in
            NSLog("%d completedUnitCount (bytes)", downloadProgress.completedUnitCount)
            if downloadProgress.fractionCompleted == 1.0 {
                expectation.fulfill()
            }
        })
        
        self.waitForExpectationsWithTimeout(10.0, handler: nil)
    }
 
    
    func testUploadProgressIsReportedForPOST() {
        var payload = "SFNetworking"
        while payload.length < 20000 {
            payload += "SFNetworking"
        }
        
        let expectation = self.expectationWithDescription("Progress should equal 1.0")
        
        self.manager.POST("post", parameters:nil, body: payload.dataUsingEncoding(NSASCIIStringEncoding), uploadProgress: { (uploadProgress:NSProgress) in
            NSLog("%f uploaded", uploadProgress.fractionCompleted)
            
            if uploadProgress.fractionCompleted == 1.0 {
                expectation.fulfill()
            }
        })

        self.waitForExpectationsWithTimeout(90.0, handler: nil)
    }
    
    */
/*
     func testUploadProgressIsReportedForStreamingPost() {
        var payload = "SFNetworking"
        while payload.length < 20000 {
            payload += "SFNetworking"
        }
        
        let expectation = self.expectationWithDescription("Progress should equal 1.0")
        
        [self.manager
        POST:@"post"
        parameters:nil
        constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileData:[payload dataUsingEncoding:NSUTF8StringEncoding] name:@"AFNetworking" fileName:@"AFNetworking" mimeType:@"text/html"];
        }
        progress:^(NSProgress * _Nonnull uploadProgress) {
        if (uploadProgress.fractionCompleted == 1.0) {
        [expectation fulfill];
        expectation = nil;
        }
        }
        success:nil
        failure:nil];
        [self waitForExpectationsWithCommonTimeoutUsingHandler:nil];
    }
  */
    // MARK: HTTP Status Codes
    
    /*
    func testThatSuccessBlockIsCalledFor200() {
        let expectation = self.expectationWithDescription("Request should succeed")
        
        let f = self.manager.GET("status/200", parameters:nil, downloadProgress:nil)
        
        f.onSuccess{ _ in expectation.fulfill() }
        
        self.waitForExpectationsWithTimeout(10.0, handler:nil)
    }
    func testThatFailureBlockIsCalledFor404() {
        let expectation = self.expectationWithDescription("Request should succeed")

        let f = self.manager.GET("status/404", parameters:nil, downloadProgress:nil)
        
        f.onFail{ _ in
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(10.0, handler:nil)
    }
    */
    /*
    func testThatResponseObjectIsEmptyFor204() {
        __block id urlResponseObject = nil;
        let expectation = self.expectationWithDescription("Request should succeed")

        [self.manager
        GET:@"status/204"
        parameters:nil
        progress:nil
        success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        urlResponseObject = responseObject;
        [expectation fulfill];
        }
        failure:nil];
        [self waitForExpectationsWithCommonTimeoutUsingHandler:nil];
        XCTAssertNil(urlResponseObject);
    }
    */
    // MARK: Rest Interface
    
    func testGET() {
        let expectation = self.expectationWithDescription("Request should succeed")

        let f = self.manager.GET("get", parameters:nil, downloadProgress:nil)
        
        f.onSuccess{ _ in expectation.fulfill() }

        self.waitForExpectationsWithTimeout(10.0, handler: nil)
    }
    
    func testHEAD() {
        let expectation = self.expectationWithDescription("Request should succeed")

        let f = self.manager.HEAD("get", parameters:nil)

        f.onSuccess{ expectation.fulfill() }
        
        self.waitForExpectationsWithTimeout(10.0, handler: nil)
    }
    
    func testPOST() {
        let expectation = self.expectationWithDescription("Request should succeed")

        let f = self.manager.POST("post", parameters:["key":"value"], body: nil, uploadProgress: nil)
        
        f.onSuccess{ expectation.fulfill() }
        
        self.waitForExpectationsWithTimeout(10.0, handler: nil)
    }
    
    /*
    func testPOSTWithConstructingBody {
        let expectation = self.expectationWithDescription("Request should succeed")

        [self.manager
        POST:@"post"
        parameters:@{@"key":@"value"}
        constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileData:[@"Data" dataUsingEncoding:NSUTF8StringEncoding]
        name:@"DataName"
        fileName:@"DataFileName"
        mimeType:@"data"];
        }
        progress:nil
        success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        XCTAssertTrue([responseObject[@"files"][@"DataName"] isEqualToString:@"Data"]);
        XCTAssertTrue([responseObject[@"form"][@"key"] isEqualToString:@"value"]);
        [expectation fulfill];
        }
        failure:nil];
        self.waitForExpectationsWithTimeout(10.0, handler: nil)
    }
    
    func testPUT {
        let expectation = self.expectationWithDescription("Request should succeed")

        [self.manager
        PUT:@"put"
        parameters:@{@"key":@"value"}
        success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        XCTAssertTrue([responseObject[@"form"][@"key"] isEqualToString:@"value"]);
        [expectation fulfill];
        }
        failure:nil];
        self.waitForExpectationsWithTimeout(10.0, handler: nil)
    }
    
    func testDELETE {
        let expectation = self.expectationWithDescription("Request should succeed")

        [self.manager
        DELETE:@"delete"
        parameters:@{@"key":@"value"}
        success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        XCTAssertTrue([responseObject[@"args"][@"key"] isEqualToString:@"value"]);
        [expectation fulfill];
        }
        failure:nil];
        self.waitForExpectationsWithTimeout(10.0, handler: nil)
    }
    
    func testPATCH {
        let expectation = self.expectationWithDescription("Request should succeed")

        [self.manager
        PATCH:@"patch"
        parameters:@{@"key":@"value"}
        success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        XCTAssertTrue([responseObject[@"form"][@"key"] isEqualToString:@"value"]);
        [expectation fulfill];
        }
        failure:nil];
        
        self.waitForExpectationsWithTimeout(10.0, handler: nil)
    }
    
    // MARK: Auth
    
    func testHiddenBasicAuthentication {
        let expectation = self.expectationWithDescription("Request should finish")
        [self.manager.requestSerializer setAuthorizationHeaderFieldWithUsername:@"user" password:@"password"];
        [self.manager
        GET:@"hidden-basic-auth/user/password"
        parameters:nil
        progress:nil
        success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [expectation fulfill];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        XCTFail(@"Request should succeed");
        [expectation fulfill];
        }];
        self.waitForExpectationsWithTimeout(10.0, handler: nil)
    }
    
    // MARK: Server Trust
    
    func testInvalidServerTrustProducesCorrectErrorForCertificatePinning {
        let expectation = self.expectationWithDescription("Request should fail")

        NSURL *googleCertificateURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"google.com" withExtension:@"cer"];
        NSData *googleCertificateData = [NSData dataWithContentsOfURL:googleCertificateURL];
        AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:@"https://apple.com/"]];
        [manager setResponseSerializer:[AFHTTPResponseSerializer serializer]];
        manager.securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate withPinnedCertificates:[NSSet setWithObject:googleCertificateData]];
        [manager
        GET:@""
        parameters:nil
        progress:nil
        success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        XCTFail(@"Request should fail");
        [expectation fulfill];
        }
        failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        XCTAssertEqualObjects(error.domain, NSURLErrorDomain);
        XCTAssertEqual(error.code, NSURLErrorCancelled);
        [expectation fulfill];
        }];
        self.waitForExpectationsWithTimeout(10.0, handler: nil)
        [manager invalidateSessionCancelingTasks:YES];
    }
    
    func testInvalidServerTrustProducesCorrectErrorForPublicKeyPinning {
        let expectation = self.expectationWithDescription("Request should fail")
        
        NSURL *googleCertificateURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"google.com" withExtension:@"cer"];
        NSData *googleCertificateData = [NSData dataWithContentsOfURL:googleCertificateURL];
        AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:@"https://apple.com/"]];
        [manager setResponseSerializer:[AFHTTPResponseSerializer serializer]];
        manager.securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModePublicKey withPinnedCertificates:[NSSet setWithObject:googleCertificateData]];
        [manager
        GET:@""
        parameters:nil
        progress:nil
        success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        XCTFail(@"Request should fail");
        [expectation fulfill];
        }
        failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        XCTAssertEqualObjects(error.domain, NSURLErrorDomain);
        XCTAssertEqual(error.code, NSURLErrorCancelled);
        [expectation fulfill];
        }];
        self.waitForExpectationsWithTimeout(10.0, handler: nil)
        [manager invalidateSessionCancelingTasks:YES];
    }
 */
}

enum TestError: ErrorType {
    case Foo
}