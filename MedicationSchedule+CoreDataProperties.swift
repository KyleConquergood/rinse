//
//  MedicationSchedule+CoreDataProperties.swift
//  rinse
//
//  Created by kyle on 2023-04-12.
//
//

import Foundation
import CoreData


extension MedicationSchedule {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MedicationSchedule> {
        return NSFetchRequest<MedicationSchedule>(entityName: "MedicationScheduleEntity")
    }

    @NSManaged public var name: String?
    @NSManaged public var time: Date
    @NSManaged public var repeatsDaily: Bool

}

extension MedicationSchedule : Identifiable {

}
