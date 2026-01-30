//
//  TodoSection.swift
//  ai_anti_doomscroll
//

import SwiftUI

struct TodoSection: View {
    @Binding var todos: [Todo]
    @Binding var newTask: String
    var phone: String
    var addTodo: () -> Void
    var deleteTodo: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Focus")
                        .font(.title3).bold()
                    Text("Complete these to keep your apps open")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                // Badge for task count
                Text("\(todos.count)")
                    .font(.caption).bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
            }

            // Task Input
            HStack(spacing: 12) {
                TextField("What's next?", text: $newTask)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                Button(action: addTodo) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(newTask.isEmpty)
            }

            // Task List
            if todos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("All caught up! Add a task to start.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 1, dash: [5])))
            } else {
                VStack(spacing: 10) {
                    ForEach(todos) { todo in
                        HStack(spacing: 15) {
                            Circle()
                                .stroke(Color.blue, lineWidth: 2)
                                .frame(width: 12, height: 12)
                            
                            Text(todo.task)
                                .font(.body)
                            
                            Spacer()
                            
                            Button(action: { deleteTodo(todo.id) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray.opacity(0.4))
                            }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}
