//
//  ViewController.swift
//  PokeFinder
//
//  Created by Ahmed T Khalil on 2/14/17.
//  Copyright © 2017 kalikans. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

import FirebaseCore
import FirebaseDatabase
import GeoFire

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet var mapView: MKMapView!
    let locationManager = CLLocationManager()
    var mapHasCenteredOnce:Bool = false
    
    //this variable is used to interact with you Firebase Database
    var geoFire:GeoFire!
    var fireBaseDBRef:FIRDatabaseReference!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        mapView.userTrackingMode = .follow
        
        //need to get location to be able to follow them
        locationManager.delegate = self
        //location authorization status
        locAuthStatus()
        
        //Initialize the GeoFire variables to store locations
        fireBaseDBRef = FIRDatabase.database().reference()
        //this is how the GeoFire object can store stuff in your database (don't forget to update rules in FireBase Database!)
        geoFire = GeoFire(firebaseRef: fireBaseDBRef)
    }
    
/****************** DISPLAYING/ADDING POKEMON IN/TO THE DATABASE *********************/
    
    //if the map region changes, then we should show the Pokemon for the new map region
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        showNearbyPokemon(location: CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude))
    }
    
    @IBAction func spotRandomPokemon(_ sender: Any) {
        //just create one wherever the map is centered (Note: Users can pan the map)
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        
        //generate a random Pokemon and at it to the database at that location
        let pokeIDRandom = Int(arc4random_uniform(151)+1)
        geoFire.setLocation(loc, forKey: "\(pokeIDRandom)")
        
        //once this is added we need refresh the pokemon that are shown
        showNearbyPokemon(location: loc)
    }
    
    func showNearbyPokemon(location:CLLocation){
        //to figure out which Pokemon we are showing, we use GeoFire (automatically tells us when things in our database enter a region of interest)
        let areaOfInterest = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10))
        let queryArea = geoFire.query(with: areaOfInterest)
        
        queryArea?.observe(.keyEntered, with: { (pokeID, pokeLocation) in
            //NOTE:MKAnnotation is a protocol, not a class on its own (that's why we create PokeAnnotation class)
            if let pokeCoordinates = pokeLocation?.coordinate, let pokeID = pokeID{
                let annotation = PokeAnnotation(coordinate: pokeCoordinates, pokemonID: Int(pokeID)!)
                
                //once this function is called, it will trigger the 'viewFor annotation' function below
                self.mapView.addAnnotation(annotation)
            }
        })
    }
    
/******************  SETTING UP CUSTOM ANNOTATIONS (USER LOCATION & POKEMON IN DATABASE)  *****************/

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        var annotationView:MKAnnotationView?
        
        if annotation.isKind(of: MKUserLocation.self){
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "User")
            annotationView?.image = UIImage(named: "ash")
        }else if let deqAV = mapView.dequeueReusableAnnotationView(withIdentifier: "Pokemon"){
            //here we check if we can use an annotation view that was already allocated rather than creating a new one
            annotationView = deqAV
            annotationView?.annotation = annotation
        }else{
            //No queued Pokemon annotation views available for reuse, so make one from scratch
            let newAnnoView = MKAnnotationView(annotation: annotation, reuseIdentifier: "Pokemon")
            annotationView = newAnnoView
        }
        
        //by the time we get here we should have an annotation view either created or dequeued (or is user location)
        if let annotationView = annotationView, let pokeAnno = annotation as? PokeAnnotation{
            //now we design the callout given the pokemon
            annotationView.image = UIImage(named: "\(pokeAnno.pokemonID)")
            
            //this is the little map that shows up in the annotation (gives you directions to Pokemon when clicked)
            //Note that the title is automatically loaded when we add the annotation
            annotationView.canShowCallout = true
            let mapBtn = UIButton(frame: CGRect(x: 0, y: 0, width: 30.0, height: 30.0))
            mapBtn.setImage(UIImage(named: "map"), for: .normal)
            annotationView.rightCalloutAccessoryView = mapBtn
        }
        
        return annotationView
    }
    
/******************  DIRECTIONS TO POKEMON IF CALL BUTTON IS CLICKED  *********************/
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let pokeAnno = view.annotation as? PokeAnnotation{
            //set the destination
            let destination = MKMapItem(placemark: MKPlacemark(coordinate: (pokeAnno.coordinate)))
            destination.name = "Drive to \(pokeAnno.pokemonName)"
            
            //come back to launch options
            let regionDistance: CLLocationDistance = 1000
            let regionSpan = MKCoordinateRegionMakeWithDistance(pokeAnno.coordinate, regionDistance, regionDistance)
            let options = [MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center), MKLaunchOptionsMapSpanKey:  NSValue(mkCoordinateSpan: regionSpan.span), MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving] as [String : Any]
            
            //open the map with the given launch options (i.e. driving enabled, etc)
            MKMapItem.openMaps(with: [destination], launchOptions: options)
        }
    }


/******************  SETTING MAP REGION WHEN THE APPLICATION FIRST LOADS  *********************/
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if !mapHasCenteredOnce{
            mapView.setRegion(MKCoordinateRegion(center: userLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)), animated: true)
            mapHasCenteredOnce=true
        }
    }
    
/******************  USER LOCATION AUTHORIZATION  *****************/
    func locAuthStatus(){
        if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedWhenInUse{
            //if authorization has been given, then annotate the user's location on the map
            mapView.showsUserLocation = true
        }else{
            //otherwise have the system ask permission for the user's location
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse{
            //annotate the user location position on the map
            mapView.showsUserLocation = true
        }else{
            locationManager.requestWhenInUseAuthorization()
        }
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

