/**
 # String-Extension.swift
## SkyNet
 
 - Author: Andrew Bradnan
 - Date: 6/5/16
 - Copyright: Copyright © 2016 SkyNet. All rights reserved.
 */

import Foundation

extension String {
    static func isNotEmpty(_ s: String?) -> Bool {
        return !(s?.isEmpty ?? true)
    }
}
