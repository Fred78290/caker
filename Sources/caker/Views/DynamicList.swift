//
//  DynamicList.swift
//  Caker
//
//  Created by Frederic BOLTZ on 10/07/2025.
//

import SwiftUI

/// A type that represents the data model for each item in the list.
///
/// The concrete type should contain stored properties for the item's data.
/// Implement `fetchAdditionalData` to asynchronously fetch additional data.
protocol ListItemModel {
	/// Fetch additional data for the item.
	mutating func fetchAdditionalData() async
}

/// The data model for the list, responsible for fetching batches of items.
///
/// Implement `fetchNextItems` to asynchronously fetch the next batch of data.
/// There is no need to store the items, this is handled by  `ListViewModel`
protocol ListModel {
	associatedtype Item: ListItemModel

	/// Initialize a new list model
	init()

	/// Asynchronously fetch the next batch of data.
	mutating func fetchNextItems(count: Int) async -> [Item]

	/// Reset to start fetching batches from the beginning.
	///
	/// Called when the list is refreshed.
	mutating func reset()

}

/// Used as a wrapper for a list item in the dynamic list.
/// It makes sure items are updated once additional data has been fetched.
final class ListItemViewModel<ItemType: ListItemModel>: Identifiable, ObservableObject {

	/// The wrapped item
	@Published var item: ItemType

	/// The index of the item in the list, starting from 0.
	var id: Int

	/// Has the fetch of additional data completed?
	var dataFetchComplete = false

	fileprivate init(item: ItemType, index: Int) {
		self.item = item
		self.id = index
	}

	@MainActor
	fileprivate func fetchAdditionalData() async {
		guard !dataFetchComplete else { return }
		await item.fetchAdditionalData()
		dataFetchComplete = true
	}
}

/// Acts as the view model for the dynamic list.
/// Handles fetching (and storing) the next batch of items as needed.
final class ListViewModel<ListModelType: ListModel>: ObservableObject {
	/// Initialize the list view model.
	/// - Parameters:
	///   - listModel:      The source that performs the actual data fetching.
	///   - itemBatchCount: Number of items to fetch in each batch. It is recommended to be greater than number of rows displayed.
	///   - prefetchMargin: How far in advance should the next batch be fetched? Greater number means more eager.
	///                     Should be less than `itemBatchCount`
	init(
		listModel: ListModelType = ListModelType(), itemBatchCount: Int = 3, prefetchMargin: Int = 1
	) {
		self.listModel = listModel
		self.itemBatchSize = itemBatchCount
		self.prefetchMargin = prefetchMargin

	}

	@Published fileprivate var list: [ListItemViewModel<ListModelType.Item>] = []

	private var listModel: ListModelType
	private let itemBatchSize: Int
	private let prefetchMargin: Int
	private var fetchingInProgress: Bool = false

	private(set) var listID: UUID = UUID()

	/// Extend the list if we are close to the end, based on the specified index
	@MainActor
	fileprivate func fetchMoreItemsIfNeeded(currentIndex: Int) async {
		guard currentIndex >= list.count - prefetchMargin,
			!fetchingInProgress
		else { return }
		fetchingInProgress = true
		let newItems = await listModel.fetchNextItems(count: itemBatchSize)
		let newListItems = newItems.enumerated().map { (index, item) in
			ListItemViewModel<ListModelType.Item>(item: item, index: list.count + index)
		}
		for listItem in newListItems {
			list.append(listItem)
			Task {
				await listItem.fetchAdditionalData()
			}
		}
		fetchingInProgress = false
	}

	/// Reset to start fetching batches from the beginning.
	///
	/// Called when the list is refreshed.
	func reset() {
		guard !fetchingInProgress else { return }
		list = []
		listID = UUID()
		listModel.reset()
	}
}

/// A type that is responsible for presenting the content of each item in a dynamic list.
///
/// The data for the item is provided through the wrapper  `itemViewModel`.
protocol DynamicListItemView: View {
	associatedtype ItemType: ListItemModel

	/// Should be declared as @ObservedObject var itemViewModel in concrete type
	var itemViewModel: ListItemViewModel<ItemType> { get }
	init(itemViewModel: ListItemViewModel<ItemType>)
}

/// The view for the dynamic list.
/// Generic parameters:
/// `ItemView` is the type that presents each list item.
/// `ListModelType` is the model list model used to fetch list data.
struct DynamicList<ItemView: DynamicListItemView, ListModelType: ListModel>: View where ListModelType.Item == ItemView.ItemType {

	@ObservedObject var listViewModel: ListViewModel<ListModelType>

	var body: some View {
		return List(listViewModel.list) { itemViewModel in
			ItemView(itemViewModel: itemViewModel)
				.task {
					await self.listViewModel.fetchMoreItemsIfNeeded(currentIndex: itemViewModel.id)
				}
		}
		.refreshable {
			listViewModel.reset()
		}
		.task {
			await self.listViewModel.fetchMoreItemsIfNeeded(currentIndex: 0)
		}
		.id(self.listViewModel.listID)
	}
}
