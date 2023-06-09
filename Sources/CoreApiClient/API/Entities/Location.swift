//
//  File.swift
//  
//
//  Created by Константин Ланин on 08.06.2023.
//

import CoreData
import CoreLocation

extension Location {
    var locationAccuracy: Double { horizontalAccuracy }
    var location: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var place: String? { city ?? country ?? region ?? district }
    // for reference
    //var place: String? { cdExhibit?.gpsArea2 ?? cdExhibit?.gpsArea1 ?? cdExhibit?.gpsArea3 ?? cdExhibit?.gpsArea4 }
}

public class Location: Base, Codable {
    enum CodingKeys: CodingKey {
        case alias,
             altitude,
             city,
             complement,
             country,
             
             district,
             horizontalAccuracy,
             id,
             latitude,
             longitude,
             
             postalCode,
             region,
             streetAddress,
             verticalAccuracy
    }
    
    public required convenience init(from decoder: Decoder) throws {
        self.init(context: cdContext)
        
        try self.decodeBase(from: decoder)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.alias = try container.decodeIfPresent(String.self, forKey: .alias)
        self.altitude = try container.decode(Double.self, forKey: .altitude)
        self.city = try container.decodeIfPresent(String.self, forKey: .city)
        self.complement = try container.decodeIfPresent(String.self, forKey: .complement)
        self.country = try container.decodeIfPresent(String.self, forKey: .country)
        
        self.district = try container.decodeIfPresent(String.self, forKey: .district)
        self.horizontalAccuracy = try container.decode(Double.self, forKey: .horizontalAccuracy)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.latitude = try container.decode(Double.self, forKey: .latitude)
        self.longitude = try container.decode(Double.self, forKey: .longitude)
        
        self.postalCode = try container.decodeIfPresent(String.self, forKey: .postalCode)
        self.region = try container.decodeIfPresent(String.self, forKey: .region)
        self.streetAddress = try container.decodeIfPresent(String.self, forKey: .streetAddress)
        self.verticalAccuracy = try container.decode(Double.self, forKey: .verticalAccuracy)
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.encodeBase(to: encoder)
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.alias, forKey: .alias)
        try container.encode(self.altitude, forKey: .altitude)
        try container.encode(self.city, forKey: .city)
        try container.encode(self.complement, forKey: .complement)
        try container.encode(self.country, forKey: .country)
        
        try container.encode(self.district, forKey: .district)
        try container.encode(self.horizontalAccuracy, forKey: .horizontalAccuracy)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.latitude, forKey: .latitude)
        try container.encode(self.longitude, forKey: .longitude)
        
        try container.encode(self.postalCode, forKey: .postalCode)
        try container.encode(self.region, forKey: .region)
        try container.encode(self.streetAddress, forKey: .streetAddress)
        try container.encode(self.verticalAccuracy, forKey: .verticalAccuracy)
    }
}
