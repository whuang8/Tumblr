//
//  PhotosViewController.swift
//  Tumblr
//
//  Created by William Huang on 1/6/17.
//  Copyright © 2017 William Huang. All rights reserved.
//

import UIKit
import AFNetworking

class PhotosViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    private var posts: [NSDictionary] = []
    private let refreshControl = UIRefreshControl()
    private var isMoreDataLoading = false
    var loadingMoreView: InfiniteScrollActivityView?
    var postsOffset = 20 // Used for getting more posts from Tumblr. Starts at 20 for the initial 20 posts received.
    
    enum DataFetchSender {
        case viewLoad
        case refreshControl
        case infiniteScroll
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        // Bind action to refresh control
        self.refreshControl.addTarget(self, action: #selector(refreshControlAction(refreshControl:)), for: UIControlEvents.valueChanged)
        // Insert reffresh control into tabe view
        self.tableView.insertSubview(self.refreshControl, at: 0)
        
        // Set up Infinite Scroll loading indicator
        let frame = CGRect(x: 0, y: tableView.contentSize.height, width: tableView.bounds.size.width, height: InfiniteScrollActivityView.defaultHeight)
        loadingMoreView = InfiniteScrollActivityView(frame: frame)
        loadingMoreView!.isHidden = true
        tableView.addSubview(loadingMoreView!)
        
        var insets = tableView.contentInset;
        insets.bottom += InfiniteScrollActivityView.defaultHeight;
        tableView.contentInset = insets
        
        getPosts(sender: DataFetchSender.viewLoad)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.posts.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PhotoCell") as! PhotoCell
        let post = posts[indexPath.row]
        if let photos = post.value(forKeyPath: "photos") as? [NSDictionary] {
            let imageUrlString = photos[0].value(forKeyPath: "original_size.url") as? String
            if let imageUrl = NSURL(string: imageUrlString!) {
                cell.photo.setImageWith(imageUrl as URL)
            }
            let rawSummary = post["summary"] as! String
            let summary = rawSummary.substring(from: rawSummary.index(rawSummary.startIndex, offsetBy: 1))
            cell.summaryLabel.text = summary
            cell.summaryLabel.sizeToFit()
        } else {
            print("No photos available")
        }
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func refreshControlAction(refreshControl: UIRefreshControl) {
        getPosts(sender: DataFetchSender.refreshControl)
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !isMoreDataLoading {
            let scrollViewContentHeight = self.tableView.contentSize.height
            let scrollOffsetThreshold = scrollViewContentHeight - self.tableView.bounds.size.height
            
            if scrollView.contentOffset.y > scrollOffsetThreshold && self.tableView.isDragging {
                isMoreDataLoading = true
                
                // Update position of loadingMoreView, and start loading indicator
                let frame = CGRect(x: 0, y: tableView.contentSize.height, width: tableView.bounds.size.width, height: InfiniteScrollActivityView.defaultHeight)
                loadingMoreView?.frame = frame
                loadingMoreView!.startAnimating()
                
                self.getPosts(sender: DataFetchSender.infiniteScroll)
            }
        }
    }
    
    func getPosts(sender: DataFetchSender) -> Void {
        var url: URL?
        if sender == DataFetchSender.infiniteScroll {
            url = URL(string:"https://api.tumblr.com/v2/blog/humansofnewyork.tumblr.com/posts/photo?offset=\(self.postsOffset)&api_key=Q6vHoaVm5L1u2ZAW1fqv3Jw48gFzYVg9P0vH0VHl3GVy6quoGV")
            self.postsOffset += 20
        } else {
            url = URL(string:"https://api.tumblr.com/v2/blog/humansofnewyork.tumblr.com/posts/photo?api_key=Q6vHoaVm5L1u2ZAW1fqv3Jw48gFzYVg9P0vH0VHl3GVy6quoGV")
        }
        let request = URLRequest(url: url!)
        let session = URLSession(
            configuration: URLSessionConfiguration.default,
            delegate:nil,
            delegateQueue:OperationQueue.main
        )
        
        let task : URLSessionDataTask = session.dataTask(
            with: request as URLRequest,
            completionHandler: { (data, response, error) in
                if let data = data {
                    if let responseDictionary = try! JSONSerialization.jsonObject(
                        with: data, options:[]) as? NSDictionary {
                        //print("responseDictionary: \(responseDictionary)")

                        let responseFieldDictionary = responseDictionary["response"] as! NSDictionary
                        
                        // Store the posts array
                        self.posts += responseFieldDictionary["posts"] as! [NSDictionary]
                        self.tableView.reloadData()
                        if sender == DataFetchSender.refreshControl {
                            self.refreshControl.endRefreshing()
                        }
                        else if sender == DataFetchSender.infiniteScroll {
                            self.loadingMoreView?.stopAnimating()
                            self.isMoreDataLoading = false
                        }
                    }
                }
        });
        task.resume()
    }
    

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let vc = segue.destination as! PhotoDetailsViewController
        let cell = sender as! PhotoCell
        vc.image = cell.photo.image
    }
}
