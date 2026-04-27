using System;
using System.Text;
using System.Threading.Tasks;
using UnityEditor;
using UnityEngine;
using UnityEngine.Networking;

public sealed class CustomModelAssistantWindow : EditorWindow
{
    private const string PrefPrefix = "ShaderCourse.CustomModelAssistant.";

    private enum Provider
    {
        OpenAICompatible,
        AnthropicClaude,
        GoogleGemini,
        OllamaLocal
    }

    [SerializeField] private Provider provider = Provider.OpenAICompatible;
    [SerializeField] private string endpoint = "https://api.openai.com/v1/chat/completions";
    [SerializeField] private string model = "gpt-4.1";
    [SerializeField] private string systemPrompt = "You are a practical Unity assistant. Answer in Chinese and focus on Unity URP shader/course development.";
    [SerializeField] private string userPrompt = "Review the current request and give a concise Unity implementation suggestion.";
    [SerializeField] private string responseText = "";

    private string apiKey = "";
    private Vector2 scroll;
    private bool isSending;

    [MenuItem("AI/Custom Model Assistant")]
    public static void Open()
    {
        GetWindow<CustomModelAssistantWindow>("Custom Model Assistant");
    }

    private void OnEnable()
    {
        provider = (Provider)EditorPrefs.GetInt(PrefPrefix + "Provider", (int)provider);
        endpoint = EditorPrefs.GetString(PrefPrefix + "Endpoint", endpoint);
        model = EditorPrefs.GetString(PrefPrefix + "Model", model);
        systemPrompt = EditorPrefs.GetString(PrefPrefix + "SystemPrompt", systemPrompt);
        apiKey = EditorPrefs.GetString(PrefPrefix + "ApiKey", "");
    }

    private void OnDisable()
    {
        SaveSettings();
    }

    private void OnGUI()
    {
        using (var scrollView = new EditorGUILayout.ScrollViewScope(scroll))
        {
            scroll = scrollView.scrollPosition;

            EditorGUILayout.LabelField("Provider", EditorStyles.boldLabel);
            EditorGUI.BeginChangeCheck();
            provider = (Provider)EditorGUILayout.EnumPopup("Type", provider);
            if (EditorGUI.EndChangeCheck())
            {
                ApplyPreset(provider);
            }

            endpoint = EditorGUILayout.TextField("Endpoint", endpoint);
            model = EditorGUILayout.TextField("Model", model);
            apiKey = EditorGUILayout.PasswordField("API Key", apiKey);

            EditorGUILayout.Space(6);
            using (new EditorGUILayout.HorizontalScope())
            {
                if (GUILayout.Button("OpenAI"))
                {
                    provider = Provider.OpenAICompatible;
                    endpoint = "https://api.openai.com/v1/chat/completions";
                    model = "gpt-4.1";
                }

                if (GUILayout.Button("DeepSeek"))
                {
                    provider = Provider.OpenAICompatible;
                    endpoint = "https://api.deepseek.com/chat/completions";
                    model = "deepseek-chat";
                }

                if (GUILayout.Button("Claude"))
                {
                    provider = Provider.AnthropicClaude;
                    endpoint = "https://api.anthropic.com/v1/messages";
                    model = "claude-sonnet-4-5";
                }

                if (GUILayout.Button("Gemini"))
                {
                    provider = Provider.GoogleGemini;
                    endpoint = "https://generativelanguage.googleapis.com/v1beta";
                    model = "gemini-2.5-pro";
                }

                if (GUILayout.Button("Ollama"))
                {
                    provider = Provider.OllamaLocal;
                    endpoint = "http://localhost:11434/api/chat";
                    model = "qwen2.5-coder";
                    apiKey = "";
                }
            }

            EditorGUILayout.Space(8);
            EditorGUILayout.LabelField("System Prompt", EditorStyles.boldLabel);
            systemPrompt = EditorGUILayout.TextArea(systemPrompt, GUILayout.MinHeight(60));

            EditorGUILayout.LabelField("User Prompt", EditorStyles.boldLabel);
            userPrompt = EditorGUILayout.TextArea(userPrompt, GUILayout.MinHeight(110));

            using (new EditorGUI.DisabledScope(isSending))
            {
                if (GUILayout.Button(isSending ? "Sending..." : "Send Test Prompt", GUILayout.Height(28)))
                {
                    SendPrompt();
                }
            }

            if (GUILayout.Button("Save Settings"))
            {
                SaveSettings();
            }

            EditorGUILayout.Space(8);
            EditorGUILayout.LabelField("Response", EditorStyles.boldLabel);
            EditorGUILayout.TextArea(responseText, GUILayout.MinHeight(220));
        }
    }

    private void ApplyPreset(Provider selectedProvider)
    {
        switch (selectedProvider)
        {
            case Provider.OpenAICompatible:
                endpoint = "https://api.openai.com/v1/chat/completions";
                model = "gpt-4.1";
                break;
            case Provider.AnthropicClaude:
                endpoint = "https://api.anthropic.com/v1/messages";
                model = "claude-sonnet-4-5";
                break;
            case Provider.GoogleGemini:
                endpoint = "https://generativelanguage.googleapis.com/v1beta";
                model = "gemini-2.5-pro";
                break;
            case Provider.OllamaLocal:
                endpoint = "http://localhost:11434/api/chat";
                model = "qwen2.5-coder";
                break;
        }
    }

    private void SaveSettings()
    {
        EditorPrefs.SetInt(PrefPrefix + "Provider", (int)provider);
        EditorPrefs.SetString(PrefPrefix + "Endpoint", endpoint);
        EditorPrefs.SetString(PrefPrefix + "Model", model);
        EditorPrefs.SetString(PrefPrefix + "SystemPrompt", systemPrompt);
        EditorPrefs.SetString(PrefPrefix + "ApiKey", apiKey);
        AssetDatabase.SaveAssets();
    }

    private async void SendPrompt()
    {
        SaveSettings();
        isSending = true;
        responseText = "Sending request...";
        Repaint();

        try
        {
            string body = BuildRequestBody();
            string url = BuildRequestUrl();
            using UnityWebRequest request = new UnityWebRequest(url, "POST");
            byte[] bodyRaw = Encoding.UTF8.GetBytes(body);
            request.uploadHandler = new UploadHandlerRaw(bodyRaw);
            request.downloadHandler = new DownloadHandlerBuffer();
            request.SetRequestHeader("Content-Type", "application/json");
            ApplyHeaders(request);

            await SendWebRequestAsync(request);

            responseText = request.result == UnityWebRequest.Result.Success
                ? ExtractResponseText(request.downloadHandler.text)
                : $"HTTP error: {request.responseCode}\n{request.error}\n\n{request.downloadHandler.text}";
        }
        catch (Exception ex)
        {
            responseText = ex.ToString();
        }
        finally
        {
            isSending = false;
            Repaint();
        }
    }

    private string BuildRequestUrl()
    {
        if (provider != Provider.GoogleGemini)
        {
            return endpoint;
        }

        string baseEndpoint = endpoint.TrimEnd('/');
        return $"{baseEndpoint}/models/{model}:generateContent?key={UnityWebRequest.EscapeURL(apiKey)}";
    }

    private void ApplyHeaders(UnityWebRequest request)
    {
        switch (provider)
        {
            case Provider.OpenAICompatible:
                request.SetRequestHeader("Authorization", $"Bearer {apiKey}");
                break;
            case Provider.AnthropicClaude:
                request.SetRequestHeader("x-api-key", apiKey);
                request.SetRequestHeader("anthropic-version", "2023-06-01");
                break;
            case Provider.OllamaLocal:
            case Provider.GoogleGemini:
                break;
        }
    }

    private string BuildRequestBody()
    {
        string safeSystem = EscapeJson(systemPrompt);
        string safeUser = EscapeJson(userPrompt);

        switch (provider)
        {
            case Provider.AnthropicClaude:
                return "{\"model\":\"" + EscapeJson(model) + "\",\"max_tokens\":2048,\"system\":\"" + safeSystem + "\",\"messages\":[{\"role\":\"user\",\"content\":\"" + safeUser + "\"}]}";
            case Provider.GoogleGemini:
                return "{\"system_instruction\":{\"parts\":[{\"text\":\"" + safeSystem + "\"}]},\"contents\":[{\"role\":\"user\",\"parts\":[{\"text\":\"" + safeUser + "\"}]}]}";
            case Provider.OllamaLocal:
                return "{\"model\":\"" + EscapeJson(model) + "\",\"stream\":false,\"messages\":[{\"role\":\"system\",\"content\":\"" + safeSystem + "\"},{\"role\":\"user\",\"content\":\"" + safeUser + "\"}]}";
            default:
                return "{\"model\":\"" + EscapeJson(model) + "\",\"messages\":[{\"role\":\"system\",\"content\":\"" + safeSystem + "\"},{\"role\":\"user\",\"content\":\"" + safeUser + "\"}],\"temperature\":0.2}";
        }
    }

    private static string EscapeJson(string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return "";
        }

        return value
            .Replace("\\", "\\\\")
            .Replace("\"", "\\\"")
            .Replace("\r", "\\r")
            .Replace("\n", "\\n")
            .Replace("\t", "\\t");
    }

    private string ExtractResponseText(string json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            return "";
        }

        string marker = provider switch
        {
            Provider.AnthropicClaude => "\"text\"",
            Provider.GoogleGemini => "\"text\"",
            Provider.OllamaLocal => "\"content\"",
            _ => "\"content\""
        };

        int markerIndex = json.IndexOf(marker, StringComparison.Ordinal);
        if (markerIndex < 0)
        {
            return json;
        }

        int colonIndex = json.IndexOf(':', markerIndex);
        if (colonIndex < 0)
        {
            return json;
        }

        int startQuote = json.IndexOf('"', colonIndex + 1);
        if (startQuote < 0)
        {
            return json;
        }

        var builder = new StringBuilder();
        bool escaping = false;
        for (int i = startQuote + 1; i < json.Length; i++)
        {
            char c = json[i];
            if (escaping)
            {
                builder.Append(c switch
                {
                    'n' => '\n',
                    'r' => '\r',
                    't' => '\t',
                    '"' => '"',
                    '\\' => '\\',
                    _ => c
                });
                escaping = false;
                continue;
            }

            if (c == '\\')
            {
                escaping = true;
                continue;
            }

            if (c == '"')
            {
                return builder.ToString();
            }

            builder.Append(c);
        }

        return json;
    }

    private static Task SendWebRequestAsync(UnityWebRequest request)
    {
        var completion = new TaskCompletionSource<bool>();
        UnityWebRequestAsyncOperation operation = request.SendWebRequest();
        operation.completed += _ => completion.TrySetResult(true);
        return completion.Task;
    }
}
