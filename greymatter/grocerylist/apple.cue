package grocerylist

let Name = "apple"
let IngressName = "\(Name)-ingress-to-\(Name)"
let EgressToRedisName = "\(Name)-egress-to-redis"

// Top level service objects enable programmatic access to service 
// metadata when exported. Tagging can be used throughout the CUE
// to do things like namespace object keys, provide contextual information
// about your service such as the name, which mesh it belongs too, etc...
// Each service object is REQUIRED to have a `config` array that contains
// all associated mesh configurations as displayed below.
Apple: {
	name:   Name
	config: [
		
		// Apple -> HTTP ingress to your container
		#domain & {
			domain_key: IngressName
			
		},
		#listener & {
			listener_key:          IngressName
			_spire_self:           Name
			_gm_observables_topic: Name
			_is_ingress:           true
			_enable_rbac:          true
		
		},
		// upstream_port -> port your service is listening on.
		// This can always remain localhost insecure since pods are
		// closed off to the rest of the world. greymatter.io recommends
		// you perform TLS termination at the sidecar level.
		#cluster & {cluster_key: IngressName, _upstream_port: 8080},
		#route & {route_key:     IngressName},
		

		// Egress redis connections specifically defined for enabling the 
		// greymatter.io health checking system. Please do not remove these 
		// otherwise services may not properly report their health to the mesh.
		#domain & {domain_key: EgressToRedisName, port: defaults.ports.redis_ingress},
		#cluster & {
			cluster_key:  EgressToRedisName
			name:         defaults.redis_cluster_name
			_spire_self:  Name
			_spire_other: defaults.redis_cluster_name
		},
		#route & {route_key: EgressToRedisName},
		#listener & {
			listener_key:  EgressToRedisName
			ip:            "127.0.0.1" // egress listeners are local-only
			port:          defaults.ports.redis_ingress
			_tcp_upstream: defaults.redis_cluster_name // NB this points at a cluster name, not key
		},


		// Edge config for the Apple service.
		// These configs are REQUIRED for your service to be accessible
		// outside your cluster/mesh.
		#cluster & {
			cluster_key:  Name
			_spire_other: Name
			
		},
		#route & {
			domain_key: "edge"
			route_key:  Name
			route_match: {
				path: "/services/grocerylist/apple/"
			}
			redirects: [
				{
					from:          "^/services/grocerylist/apple$"
					to:            route_match.path
					redirect_type: "permanent"
				},
			]
			prefix_rewrite: "/"
		},

		// Grey Matter catalog service definition for apple
		#catalog_entry & {
			name:                      Name
			mesh_id:                   mesh.metadata.name
			service_id:                Name
			version:                   "v1.0.0"
			description:               "EDIT ME: service description goes here"
			
			api_endpoint:              "http://\(defaults.edge.endpoint)/services/grocerylist/\(Name)/"
			api_spec_endpoint:         "http://\(defaults.edge.endpoint)/services/grocerylist/\(Name)/"
			business_impact:           "low"
			enable_instance_metrics:   true
			enable_historical_metrics: false
		},

		// Shared apple proxy object. All configs
		// become associated with this object with the exception
		// of the catalog definition. Proxy objects are REQUIRED
		// to register your service in a Grey Matter mesh and MUST
		// be created after all other objects.
		#proxy & {
			proxy_key: Name
			domain_keys: [IngressName,EgressToRedisName]
			listener_keys: [IngressName,EgressToRedisName]
		}
	]
}
