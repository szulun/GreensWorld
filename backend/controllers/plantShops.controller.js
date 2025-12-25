// controllers/plantShops.controller.js
import { z } from 'zod';

// --- Query schema with enhanced search options
const Query = z.object({
  lat: z.coerce.number().refine(v => v >= -90 && v <= 90, 'lat must be between -90 and 90').optional(),
  lng: z.coerce.number().refine(v => v >= -180 && v <= 180, 'lng must be between -180 and 180').optional(),
  radius: z.coerce.number().default(5000).transform(v => Math.min(Math.max(v, 100), 50_000)),
  q: z.string().trim().optional(),              // keyword search (succulents, roses, etc.)
  place: z.string().trim().optional(),          // place name search (Central Park, Brooklyn, etc.)
  types: z.string().trim().optional(),
  page: z.coerce.number().default(1).transform(v => Math.max(1, v)),
  limit: z.coerce.number().default(50).transform(v => Math.min(Math.max(1, v), 100)),
});

// Plant-related search types for Google Places
const PLANT_SHOP_TYPES = [
  'florist',
  'store', // Will filter by keywords
  'establishment'
];

// Plant-related keywords for search
const PLANT_KEYWORDS = [
  'plant nursery',
  'garden center', 
  'plant shop',
  'greenhouse',
  'florist',
  'succulents',
  'houseplants',
  'botanical'
];

// Google Places API client with enhanced search
class PlacesAPIClient {
  constructor() {
    this.apiKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;
    this.baseUrl = 'https://maps.googleapis.com/maps/api/place';
    this.geocodeUrl = 'https://maps.googleapis.com/maps/api/geocode';
  }

  async geocodePlace(placeName) {
    if (!this.apiKey) {
      throw new Error('Google Maps API key not configured');
    }

    const params = new URLSearchParams({
      address: placeName,
      key: this.apiKey
    });

    const response = await fetch(`${this.geocodeUrl}/json?${params}`);
    
    if (!response.ok) {
      throw new Error(`Geocoding API error: ${response.status}`);
    }

    const data = await response.json();
    
    if (data.status !== 'OK') {
      throw new Error(`Geocoding status: ${data.status}`);
    }

    if (data.results.length === 0) {
      throw new Error(`Place "${placeName}" not found`);
    }

    return data.results[0].geometry.location;
  }

  async nearbySearch(lat, lng, radius, keyword = '') {
    if (!this.apiKey) {
      throw new Error('Google Maps API key not configured');
    }

    const params = new URLSearchParams({
      location: `${lat},${lng}`,
      radius: Math.min(radius, 50000).toString(),
      type: 'store',
      keyword: keyword || 'plant nursery garden center',
      key: this.apiKey
    });

    const response = await fetch(`${this.baseUrl}/nearbysearch/json?${params}`);
    
    if (!response.ok) {
      throw new Error(`Places API error: ${response.status}`);
    }

    const data = await response.json();
    
    if (data.status !== 'OK' && data.status !== 'ZERO_RESULTS') {
      throw new Error(`Places API status: ${data.status}`);
    }

    return data;
  }

  async textSearch(query, lat = null, lng = null, radius = 50000) {
    if (!this.apiKey) {
      throw new Error('Google Maps API key not configured');
    }

    const params = new URLSearchParams({
      query: `${query} plant shop garden center nursery`,
      key: this.apiKey
    });

    // If location provided, bias results to that area
    if (lat && lng) {
      params.append('location', `${lat},${lng}`);
      params.append('radius', radius.toString());
    }

    const response = await fetch(`${this.baseUrl}/textsearch/json?${params}`);
    
    if (!response.ok) {
      throw new Error(`Places API error: ${response.status}`);
    }

    const data = await response.json();
    
    if (data.status !== 'OK' && data.status !== 'ZERO_RESULTS') {
      throw new Error(`Places API status: ${data.status}`);
    }

    return data;
  }

  async getPlaceDetails(placeId) {
    const params = new URLSearchParams({
      place_id: placeId,
      fields: 'name,formatted_address,geometry,rating,types,opening_hours,formatted_phone_number,website,price_level',
      key: this.apiKey
    });

    const response = await fetch(`${this.baseUrl}/details/json?${params}`);
    const data = await response.json();

    if (data.status === 'OK') {
      return data.result;
    }
    return null;
  }
}

const placesClient = new PlacesAPIClient();

// Filter function to identify plant-related businesses
function isPlantRelated(place) {
  const name = place.name?.toLowerCase() || '';
  const types = place.types || [];
  const address = place.vicinity?.toLowerCase() || '';
  
  // Check if it's a florist
  if (types.includes('florist')) return true;
  
  // Check for plant-related keywords in name
  const plantKeywords = [
    'plant', 'nursery', 'garden', 'greenhouse', 'botanical', 
    'succulent', 'flower', 'flora', 'green', 'bloom'
  ];
  
  if (plantKeywords.some(keyword => name.includes(keyword))) return true;
  
  // Exclude obviously non-plant stores
  const excludeKeywords = [
    'restaurant', 'food', 'bar', 'pharmacy', 'gas', 'bank', 
    'hotel', 'hospital', 'auto', 'clothing', 'electronics'
  ];
  
  if (excludeKeywords.some(keyword => name.includes(keyword) || address.includes(keyword))) {
    return false;
  }
  
  return false;
}

// Calculate distance between two points
function distanceM(lat1, lng1, lat2, lng2) {
  const R = 6371; // km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a =
    Math.sin(dLat/2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng/2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)) * 1000;
}

export const getNearbyPlantShops = async (req, res) => {
  try {
    const parsed = Query.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid query parameters',
        details: parsed.error.issues.map(i => i.message)
      });
    }

    let { lat, lng, radius, q, place, types, page, limit } = parsed.data;

    // Debug: Check if API key is configured
    console.log('Checking API key...');
    console.log('NEXT_PUBLIC_GOOGLE_MAPS_API_KEY exists:', !!process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY);
    console.log('API key length:', process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY?.length || 0);
    
    if (!process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY) {
      console.log('No Google Maps API key found');
      console.log('Available env vars:', Object.keys(process.env).filter(k => k.includes('GOOGLE')));
      return res.status(500).json({
        success: false,
        error: 'Google Maps API key not configured',
        message: 'Please set NEXT_PUBLIC_GOOGLE_MAPS_API_KEY in your environment variables'
      });
    }

    let searchLocation = null;
    let placesData = null;

    // Handle different search scenarios
    if (place && (!lat || !lng)) {
      // Scenario 1: Search by place name (e.g., "Central Park", "Brooklyn")
      try {
        const location = await placesClient.geocodePlace(place);
        lat = location.lat;
        lng = location.lng;
        searchLocation = { lat, lng, resolvedFrom: place };
      } catch (error) {
        // If geocoding fails, suggest using coordinates instead
        return res.status(400).json({
          success: false,
          error: `Could not find location: ${place}`,
          message: error.message,
          suggestion: 'Try providing latitude and longitude coordinates instead, or enable the Geocoding API in Google Cloud Console'
        });
      }
    } else if (!lat || !lng) {
      // No coordinates and no place provided
      return res.status(400).json({
        success: false,
        error: 'Either coordinates (lat, lng) or place name is required',
        suggestion: 'Try: ?lat=40.7829&lng=-73.9654&q=succulents for Central Park area'
      });
    } else {
      searchLocation = { lat, lng };
    }

    // Choose search method based on query type
    if (q && (q.includes('near') || q.includes('close to') || place)) {
      // Scenario 2: Text search with location bias (e.g., "succulents near Central Park")
      const searchQuery = q.replace(/near|close to/gi, '').trim();
      placesData = await placesClient.textSearch(searchQuery, lat, lng, radius);
    } else if (q) {
      // Scenario 3: Keyword search in area (e.g., "succulents", "roses", "indoor plants")
      const keyword = `plant nursery garden center ${q}`;
      placesData = await placesClient.nearbySearch(lat, lng, radius, keyword);
    } else {
      // Scenario 4: General plant shops in area
      placesData = await placesClient.nearbySearch(lat, lng, radius);
    }
    
    if (!placesData.results || placesData.results.length === 0) {
      return res.json({
        success: true,
        summary: {
          total: 0,
          page,
          limit, 
          pages: 1,
          searchLocation,
          radiusMeters: radius,
          searchQuery: q || null,
          resolvedPlace: place || null,
        },
        features: [],
      });
    }

    // Process and filter results
    const processedShops = placesData.results
      .filter(place => {
        if (!place.name || !place.geometry?.location) return false;
        
        // For text searches, be more lenient with filtering
        if (q && q.length > 2) return true;
        
        // Apply plant-related filtering for general searches
        if (!q && !isPlantRelated(place)) return false;
        
        return true;
      })
      .map(place => {
        const { lat: pLat, lng: pLng } = place.geometry.location;
        const distance = distanceM(lat, lng, pLat, pLng);
        
        return {
          id: place.place_id,
          name: place.name,
          address: place.vicinity || place.formatted_address || '',
          lat: pLat,
          lng: pLng,
          rating: place.rating || null,
          types: place.types || [],
          distanceMeters: Math.round(distance),
          priceLevel: place.price_level || null,
          isOpen: place.opening_hours?.open_now || null,
          placeId: place.place_id
        };
      })
      .filter(shop => shop.distanceMeters <= radius)
      .sort((a, b) => a.distanceMeters - b.distanceMeters);

    // Apply type filters if specified
    let filtered = processedShops;
    
    if (types) {
      const typeSet = new Set(types.split(',').map(s => s.trim().toLowerCase()).filter(Boolean));
      filtered = filtered.filter(shop => 
        shop.types.some(type => typeSet.has(String(type).toLowerCase()))
      );
    }

    // Apply pagination
    const start = (page - 1) * limit;
    const end = start + limit;
    const pageItems = filtered.slice(start, end);

    // Set cache headers
    res.set('Cache-Control', 'public, max-age=300');

    res.json({
      success: true,
      summary: {
        total: filtered.length,
        page,
        limit,
        pages: Math.max(1, Math.ceil(filtered.length / limit)),
        searchLocation,
        radiusMeters: radius,
        searchQuery: q || null,
        resolvedPlace: place || null,
      },
      features: pageItems,
    });

  } catch (error) {
    console.error('Error fetching plant shops:', error);
    console.error('Error stack:', error.stack);
    
    // Don't expose API errors to client in production
    res.status(500).json({
      success: false,
      error: 'Failed to fetch plant shops',
      message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error',
      details: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
};

// Optional: Get detailed info for a specific plant shop
export const getPlantShopDetails = async (req, res) => {
  try {
    const { placeId } = req.params;
    
    if (!placeId) {
      return res.status(400).json({
        success: false,
        error: 'Place ID is required'
      });
    }

    const details = await placesClient.getPlaceDetails(placeId);
    
    if (!details) {
      return res.status(404).json({
        success: false,
        error: 'Plant shop not found'
      });
    }

    res.json({
      success: true,
      shop: {
        id: details.place_id,
        name: details.name,
        address: details.formatted_address,
        lat: details.geometry.location.lat,
        lng: details.geometry.location.lng,
        rating: details.rating,
        types: details.types,
        phone: details.formatted_phone_number,
        website: details.website,
        priceLevel: details.price_level,
        openingHours: details.opening_hours,
      }
    });

  } catch (error) {
    console.error('Error fetching shop details:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch shop details'
    });
  }
};