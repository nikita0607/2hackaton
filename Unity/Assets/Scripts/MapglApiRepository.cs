using System;
using System.Collections.Generic;
using System.Globalization;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.Networking;

namespace TwoGis
{
    /// <summary>
    /// Provides strongly-typed access to the subset of 2GIS Catalog and Digital Twin endpoints
    /// described in <c>Assets/Resources/openapi_mapgl.yaml</c>.
    /// </summary>
    public class MapglApiRepository
    {
        private const string CatalogBaseUrl = "https://catalog.api.2gis.com/3.0";
        private const string ModelServiceBaseUrl = "https://disk.2gis.com/digital-twin/models_s3";

        /// <summary>
        /// Performs a geocode search for buildings by coordinates.
        /// </summary>
        /// <param name="latitude">Latitude in degrees.</param>
        /// <param name="longitude">Longitude in degrees.</param>
        /// <param name="apiKey">2GIS API key.</param>
        /// <param name="radiusMeters">Optional search radius in meters (defaults to API behaviour).</param>
        /// <returns><see cref="GeocodeResponse"/> that includes buildings found near the point.</returns>
        public Task<GeocodeResponse> SearchBuildingsAsync(double latitude, double longitude, string apiKey, int? radiusMeters = null)
        {
            if (string.IsNullOrWhiteSpace(apiKey))
            {
                throw new ArgumentException("API key is required", nameof(apiKey));
            }

            var query = new Dictionary<string, string>
            {
                ["lat"] = latitude.ToString(CultureInfo.InvariantCulture),
                ["lon"] = longitude.ToString(CultureInfo.InvariantCulture),
                ["type"] = "building",
                ["key"] = apiKey
            };

            if (radiusMeters.HasValue)
            {
                query["radius"] = radiusMeters.Value.ToString(CultureInfo.InvariantCulture);
            }

            return GetAndDeserializeAsync<GeocodeResponse>(CatalogBaseUrl, "/items/geocode", query);
        }

        /// <summary>
        /// Gets extended information about a building by its identifier.
        /// </summary>
        /// <param name="buildingId">Identifier of the building returned by geocode or places API.</param>
        /// <param name="apiKey">2GIS API key.</param>
        /// <param name="fields">Optional comma-separated list of additional fields to include.</param>
        /// <returns><see cref="BuildingDetailsResponse"/> with building details.</returns>
        public Task<BuildingDetailsResponse> GetBuildingDetailsAsync(string buildingId, string apiKey, string fields = null)
        {
            if (string.IsNullOrWhiteSpace(buildingId))
            {
                throw new ArgumentException("Building id is required", nameof(buildingId));
            }

            if (string.IsNullOrWhiteSpace(apiKey))
            {
                throw new ArgumentException("API key is required", nameof(apiKey));
            }

            var query = new Dictionary<string, string>
            {
                ["id"] = buildingId,
                ["key"] = apiKey
            };

            if (!string.IsNullOrWhiteSpace(fields))
            {
                query["fields"] = fields;
            }

            return GetAndDeserializeAsync<BuildingDetailsResponse>(CatalogBaseUrl, "/items/byid", query);
        }

        /// <summary>
        /// Lists available 3D models for buildings. This endpoint is demonstrational according to the spec.
        /// </summary>
        /// <param name="buildingId">Optional building ID to filter models.</param>
        /// <returns><see cref="ModelListResponse"/> describing accessible models.</returns>
        public Task<ModelListResponse> GetModelsAsync(string buildingId = null)
        {
            var query = new Dictionary<string, string>();

            if (!string.IsNullOrWhiteSpace(buildingId))
            {
                query["building_id"] = buildingId;
            }

            return GetAndDeserializeAsync<ModelListResponse>(ModelServiceBaseUrl, "/models", query);
        }

        /// <summary>
        /// Retrieves metadata for a 3D model by its identifier.
        /// </summary>
        /// <param name="modelId">Identifier of the digital twin model.</param>
        /// <returns><see cref="ModelDetail"/> containing location of the glTF/GLB asset and metadata.</returns>
        public Task<ModelDetail> GetModelDetailAsync(string modelId)
        {
            if (string.IsNullOrWhiteSpace(modelId))
            {
                throw new ArgumentException("Model id is required", nameof(modelId));
            }

            return GetAndDeserializeAsync<ModelDetail>(ModelServiceBaseUrl, $"/models/{modelId}");
        }

        private async Task<T> GetAndDeserializeAsync<T>(string baseUrl, string relativePath, Dictionary<string, string> query = null)
        {
            var url = BuildUrl(baseUrl, relativePath, query);

            using (var request = UnityWebRequest.Get(url))
            {
                var operation = request.SendWebRequest();
                while (!operation.isDone)
                {
                    await Task.Yield();
                }

                if (!RequestSucceeded(request))
                {
                    var message = string.IsNullOrEmpty(request.error) ? "Request failed" : request.error;
                    throw new InvalidOperationException($"2GIS request to '{url}' failed: {message}");
                }

                var json = request.downloadHandler.text;

                if (string.IsNullOrEmpty(json))
                {
                    throw new InvalidOperationException($"2GIS request to '{url}' returned an empty response.");
                }

                try
                {
                    return JsonUtility.FromJson<T>(json);
                }
                catch (ArgumentException parseException)
                {
                    throw new InvalidOperationException("Failed to parse 2GIS response JSON.", parseException);
                }
            }
        }

        private static string BuildUrl(string baseUrl, string relativePath, Dictionary<string, string> query)
        {
            var path = relativePath ?? string.Empty;
            if (!path.StartsWith("/", StringComparison.Ordinal))
            {
                path = "/" + path;
            }

            var url = baseUrl.TrimEnd('/') + path;

            if (query == null || query.Count == 0)
            {
                return url;
            }

            var first = true;
            foreach (var kvp in query)
            {
                if (string.IsNullOrEmpty(kvp.Value))
                {
                    continue;
                }

                url += first ? "?" : "&";
                first = false;
                url += UnityWebRequest.EscapeURL(kvp.Key) + "=" + UnityWebRequest.EscapeURL(kvp.Value);
            }

            return url;
        }

        private static bool RequestSucceeded(UnityWebRequest request)
        {
#if UNITY_2020_1_OR_NEWER
            return request.result == UnityWebRequest.Result.Success;
#else
            return !request.isNetworkError && !request.isHttpError;
#endif
        }
    }

    [Serializable]
    public class Meta
    {
        public string api_version;
        public int code;
        public string issue_date;
    }

    [Serializable]
    public class GeocodeItem
    {
        public string id;
        public string name;
        public string full_name;
        public string type;
    }

    [Serializable]
    public class GeocodeResult
    {
        public GeocodeItem[] items;
        public int total;
    }

    [Serializable]
    public class GeocodeResponse
    {
        public Meta meta;
        public GeocodeResult result;
    }

    [Serializable]
    public class StructureInfo
    {
        public string material;
        public int apartments_count;
        public int porch_count;
        public string floor_type;
        public string gas_type;
        public int year_of_construction;
        public int elevators_count;
        public bool is_in_emergency_state;
        public string project_type;
        public string chs_name;
        public string chs_category;
    }

    [Serializable]
    public class BuildingPoint
    {
        public double lon;
        public double lat;
    }

    [Serializable]
    public class BuildingDetails
    {
        public string id;
        public string name;
        public string address_name;
        public string type;
        public int floors;
        public BuildingPoint point;
        public StructureInfo structure_info;
    }

    [Serializable]
    public class BuildingDetailsResult
    {
        public BuildingDetails[] items;
        public int total;
    }

    [Serializable]
    public class BuildingDetailsResponse
    {
        public Meta meta;
        public BuildingDetailsResult result;
    }

    [Serializable]
    public class Model
    {
        public string id;
        public string building_id;
        public string url;
        public string description;
    }

    [Serializable]
    public class ModelListResponse
    {
        public Model[] models;
    }

    [Serializable]
    public class ModelDetail
    {
        public string id;
        public string building_id;
        public string url;
        public string format;
        public float[] scale;
        public float[] rotation;
        public float[] translate;
        public string preview_image;
        public string description;
    }
}
