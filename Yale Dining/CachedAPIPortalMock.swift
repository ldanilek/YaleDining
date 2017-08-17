//
//  CachedAPIPortalMock.swift
//  Yale
//
//  Created by Lee on 3/23/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import UIKit

class CachedAPIPortalMock: NSObject, InternetInterface {
    public func fetchFromAPI(url: URL, cacheTTL: TimeInterval, forceFetch: Bool) -> Promise<Data> {
        for (expectedURL, expectedCacheTTL, expectedForceFetch, promise) in self.expected.reversed() {
            if expectedURL == url && expectedCacheTTL == cacheTTL && expectedForceFetch == forceFetch {
                return promise
            }
        }
        return Promise() {
            return .Excuse(NSError(domain: "mock.api_portal.sdmp.yale", code: 0, userInfo: nil))
        }
    }
    
    private var expected = [(URL, TimeInterval, Bool, Promise<Data>)]()
    public func expect(url: URL, cacheTTL: TimeInterval = 0, forceFetch: Bool = false, andReturn promise: Promise<Data>) {
        expected.append(url, cacheTTL, forceFetch, promise)
    }
}

