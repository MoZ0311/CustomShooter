Shader "HPMaskTint/URP"
{
    Properties
    {
        _Albedo("Albedo", 2D) = "white" {}
        _Mask("Mask", 2D) = "white" {}
        _EmissionTex("EmissionTex", 2D) = "white" {}
        [Normal] _Normal("Normal", 2D) = "bump" {}

        _NormalPower("NormalPower", Range(0, 6)) = 2
        _Smoothness("Smoothness", Range(0, 1)) = 0
        _Specular("Specular", Color) = (0,0,0,0)

        _Color01("Color01", Color) = (0,0,0,0)
        _Color02("Color02", Color) = (0,0,0,0)
        _Color03("Color03", Color) = (0,0,0,0)

        _EmissionColor("EmissionColor", Color) = (0,0,0,0)

        _EmissionPower("EmissionPower", Range(0, 6)) = 2
        _Color01Power("Color01Power", Range(0, 6)) = 2
        _Color02Power("Color02Power", Range(0, 6)) = 2
        _Color03Power("Color03Power", Range(0, 6)) = 2
        _OverallPower("OverallPower", Range(0, 6)) = 2
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        Cull Back
        ZWrite On

        Pass
        {
            Name "ForwardLit"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag

            // Main light shadows.
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_SCREEN

            // Additional lights.
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS

            // Additional light shadows.
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            // Soft shadows.
            #pragma multi_compile _ _SHADOWS_SOFT

            // Lightmaps / fog.
            #pragma multi_compile_fog
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_Albedo);
            SAMPLER(sampler_Albedo);

            TEXTURE2D(_Mask);
            SAMPLER(sampler_Mask);

            TEXTURE2D(_EmissionTex);
            SAMPLER(sampler_EmissionTex);

            TEXTURE2D(_Normal);
            SAMPLER(sampler_Normal);

            CBUFFER_START(UnityPerMaterial)
                float4 _Albedo_ST;
                float4 _Mask_ST;
                float4 _EmissionTex_ST;
                float4 _Normal_ST;

                float4 _Color01;
                float4 _Color02;
                float4 _Color03;
                float4 _EmissionColor;
                float4 _Specular;

                float _NormalPower;
                float _Smoothness;
                float _EmissionPower;
                float _Color01Power;
                float _Color02Power;
                float _Color03Power;
                float _OverallPower;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float4 tangentWS  : TEXCOORD2;
                float2 uv         : TEXCOORD3;
                float3 viewDirWS  : TEXCOORD4;
                half4 fogFactorAndVertexLight : TEXCOORD5;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings Vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs positionInputs =
                    GetVertexPositionInputs(input.positionOS.xyz);

                VertexNormalInputs normalInputs =
                    GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                output.normalWS = NormalizeNormalPerVertex(normalInputs.normalWS);

                output.tangentWS = float4(
                    normalInputs.tangentWS,
                    input.tangentOS.w
                );

                output.uv = input.uv;
                output.viewDirWS =
                    GetWorldSpaceNormalizeViewDir(positionInputs.positionWS);

                half3 vertexLight =
                    VertexLighting(positionInputs.positionWS, output.normalWS);

                output.fogFactorAndVertexLight =
                    half4(ComputeFogFactor(positionInputs.positionCS.z), vertexLight);

                return output;
            }

            half3 CalculateTintedAlbedo(float4 albedo, float4 mask)
            {
                // Preserve the original HPMaskTint calculation:
                //
                // min(Mask.R, Color01) * Color01Power
                // + min(Mask.G, Color02) * Color02Power
                // + min(Mask.B, Color03) * Color03Power
                //
                // followed by:
                // lerp(Albedo,
                //      saturate(Albedo * tint) * OverallPower,
                //      Mask.R + Mask.G + Mask.B)

                float4 color01Contribution =
                    min(mask.r, _Color01) * _Color01Power;

                float4 color02Contribution =
                    min(mask.g, _Color02) * _Color02Power;

                float4 color03Contribution =
                    min(mask.b, _Color03) * _Color03Power;

                float4 tint =
                    color01Contribution +
                    color02Contribution +
                    color03Contribution;

                float4 tinted =
                    saturate(albedo * tint) * _OverallPower;

                float maskWeight =
                    mask.r + mask.g + mask.b;

                return lerp(
                    albedo.rgb,
                    tinted.rgb,
                    maskWeight
                );
            }

            half3 CalculateEmission(float4 emissionTex)
            {
                return saturate(emissionTex.rgb * _EmissionColor.rgb)
                       * _EmissionPower;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);

                float2 uvAlbedo =
                    TRANSFORM_TEX(input.uv, _Albedo);

                float2 uvMask =
                    TRANSFORM_TEX(input.uv, _Mask);

                float2 uvEmission =
                    TRANSFORM_TEX(input.uv, _EmissionTex);

                float2 uvNormal =
                    TRANSFORM_TEX(input.uv, _Normal);

                float4 albedoSample =
                    SAMPLE_TEXTURE2D(
                        _Albedo,
                        sampler_Albedo,
                        uvAlbedo
                    );

                float4 maskSample =
                    SAMPLE_TEXTURE2D(
                        _Mask,
                        sampler_Mask,
                        uvMask
                    );

                float4 emissionSample =
                    SAMPLE_TEXTURE2D(
                        _EmissionTex,
                        sampler_EmissionTex,
                        uvEmission
                    );

                float3 normalTS =
                    UnpackNormalScale(
                        SAMPLE_TEXTURE2D(
                            _Normal,
                            sampler_Normal,
                            uvNormal
                        ),
                        _NormalPower
                    );

                half3 albedo =
                    CalculateTintedAlbedo(
                        albedoSample,
                        maskSample
                    );

                half3 emission =
                    CalculateEmission(emissionSample);

                // Build tangent-to-world normal.
                float3 normalWS = NormalizeNormalPerPixel(
                    TransformTangentToWorld(
                        normalTS,
                        half3x3(
                            normalize(input.tangentWS.xyz),
                            normalize(cross(
                                input.normalWS,
                                input.tangentWS.xyz
                            ) * input.tangentWS.w),
                            normalize(input.normalWS)
                        )
                    )
                );

                InputData inputData = (InputData)0;

                inputData.positionWS = input.positionWS;
                inputData.normalWS = normalWS;
                inputData.viewDirectionWS =
                    SafeNormalize(input.viewDirWS);

                inputData.shadowCoord =
                    TransformWorldToShadowCoord(input.positionWS);

                inputData.fogCoord =
                    input.fogFactorAndVertexLight.x;

                inputData.vertexLighting =
                    input.fogFactorAndVertexLight.yzw;

                inputData.bakedGI =
                    SampleSH(normalWS);

                SurfaceData surfaceData = (SurfaceData)0;

                surfaceData.albedo = albedo;
                surfaceData.specular = _Specular.rgb;
                surfaceData.metallic = 0.0;
                surfaceData.smoothness = _Smoothness;
                surfaceData.normalTS = normalTS;
                surfaceData.emission = emission;
                surfaceData.occlusion = 1.0;
                surfaceData.alpha = 1.0;

                half4 color =
                    UniversalFragmentPBR(
                        inputData,
                        surfaceData
                    );

                color.rgb =
                    MixFog(color.rgb, inputData.fogCoord);

                return color;
            }

            ENDHLSL
        }

        // Use URP's standard shadow caster/depth implementations.
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
    }

    FallBack Off
}
