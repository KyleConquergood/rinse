//
//  ProgressRingView.swift
//  rinse
//
//  Created by kyle on 2023-04-12.
//

import SwiftUI

struct ProgressRingView: View {
    var weeklyProgress: CGFloat
    var monthlyProgress: CGFloat
    var lineWidth: CGFloat = 15
    var weeklyColors: [Color] = [.blue, .green]
    var monthlyColors: [Color] = [.orange, .red]

    var body: some View {
        VStack {
            ZStack {
                // Monthly progress ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                    .padding(lineWidth)
                Circle()
                    .trim(from: 0, to: monthlyProgress)
                    .stroke(monthlyColors.first ?? .orange, lineWidth: lineWidth)
                    .rotationEffect(.degrees(-90))
                    .padding(lineWidth)
                ZStack {
                    Rectangle()
                        .stroke(monthlyColors.first ?? .orange, lineWidth: 2)
                        .frame(width: 60, height: 30)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    Text("\(Int(monthlyProgress * 100))%")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
                .offset(y: -(lineWidth / 2) - 20)

                // Weekly progress ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: weeklyProgress)
                    .stroke(weeklyColors.first ?? .blue, lineWidth: lineWidth)
                    .rotationEffect(.degrees(-90))
                ZStack {
                    Rectangle()
                        .stroke(weeklyColors.first ?? .blue, lineWidth: 2)
                        .frame(width: 60, height: 30)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    Text("\(Int(weeklyProgress * 100))%")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
                .offset(y: (lineWidth / 2) + 20)
            }

            // Indicators
            HStack {
                HStack {
                    Circle()
                        .fill(weeklyColors.first ?? .blue)
                        .frame(width: 10, height: 10)
                    Text("Weekly")
                        .font(.system(size: 16))
                        .foregroundColor(Color.primary)
                }
                Spacer()
                HStack {
                    Circle()
                        .fill(monthlyColors.first ?? .orange)
                        .frame(width: 10, height: 10)
                    Text("Monthly")
                        .font(.system(size: 16))
                        .foregroundColor(Color.primary)
                }
            }
        }
    }
}




