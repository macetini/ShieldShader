Shader "Custom/ClassicShield"
{
	Properties
	{		
		[HDR] _Color("Color", Color) = (0,0,0,0)
		[HDR] _GlowColor("Glow Color", Color) = (1, 1, 1, 1)
		_FadeLength("Intersection Fade Length", Range(0, 2)) = 0.15		
		_HitForceMultiplier("Hit Force Multiplier", Range(0, 1.0)) = 0.15
		[HDR] _HitColor("Hit Color", Color) = (1, 1, 1, 1)
		_HitColorIntensity("Hit Color Intensity", Range(0.0, 5.0)) = 1
		_HitAlfaIntensity("Hit Alfa Intensity", Range(0.0, 5.0)) = 1
		_HitEffectBorder("Hit Effect Border", Range(0.01, 1.0)) = 0.25
		[HDR] _FresnelColor("Fresnel Color", Color) = (1,1,1,1)
		_FresnelTex("Fresnel Texture", 2D) = "white" {}
		[PowerSlider(4)] _FresnelExponent("Fresnel Exponent", Range(0.25, 4)) = 1
		_ScrollSpeedU("Scroll U Speed",float) = 2
		_ScrollSpeedV("Scroll V Speed",float) = 0
	}

	SubShader
	{	
		Lighting Off 
		Blend SrcAlpha OneMinusSrcAlpha
		ZWrite Off
		Cull Off

		Tags{ "RenderType" = "Transparent" "Queue" = "Transparent"}
		//Tags{ "Queue" = "Overlay" "IgnoreProjector" = "True" "RenderType" = "Transparent" }

		Pass
		{
			CGPROGRAM
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float3 objectPosition : TEXCOORD1;
				float3 viewDir : TEXCOORD2;
				float3 worldNormal : NORMAL;
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;	

			int _HitsCount = 0;
			float _HitsRadius[10];
			float3 _HitsObjectPosition[10];
			float _HitsIntensity[10];

			fixed3 _HitColor;
			fixed _HitForceMultiplier;
			float _HitEffectBorder;

			float _HitColorIntensity;
			float _HitAlfaIntensity;

			fixed _ScrollSpeedU;
			fixed _ScrollSpeedV;

			float GetColorRing(float intensity, float radius, float dist)
			{
				float currentRadius = lerp(0, radius, 1.0 - intensity);
				return intensity * (1.0 - smoothstep(currentRadius, currentRadius + _HitEffectBorder, dist) - (1.0 - smoothstep(currentRadius - _HitEffectBorder, currentRadius, dist)));
			}

			float GetHitColorFactor(float3 objectPosition)
			{
				float factor = 0.0;

				for (int i = 0; i < _HitsCount; i++)
				{
					float distanceToHit = distance(objectPosition, _HitsObjectPosition[i]);					
					factor += GetColorRing(_HitsIntensity[i], _HitsRadius[i], distanceToHit);
				}

				factor = saturate(factor);

				return factor;
			} 

			float GetHitAlphaFactor(float3 objectPosition)
			{
				float factor = 0.0;

				for (int i = 0; i < _HitsCount; i++)
				{
					float distanceToHit = distance(objectPosition, _HitsObjectPosition[i]);
					//Alpha circle
					float currentRadius = lerp(0, _HitsRadius[i] - _HitEffectBorder, 1.0 - _HitsIntensity[i]);
					factor += _HitsIntensity[i] * (1.0 - smoothstep(0, currentRadius, distanceToHit));					
				}

				factor = saturate(factor);// *_HitAlfaIntensity);

				return factor;
			}

			v2f vert(appdata v)
			{
				float3 objectPosition = v.vertex;
				objectPosition += v.normal * _HitForceMultiplier * GetHitColorFactor(objectPosition);

				v2f o;
				o.vertex = UnityObjectToClipPos(objectPosition);

				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.x += _Time * _ScrollSpeedU;
				o.uv.y += _Time * _ScrollSpeedV;				

				o.objectPosition = objectPosition;

				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.viewDir = ObjSpaceViewDir(v.vertex);

				return o;
			}

			sampler2D _CameraDepthTexture;
			fixed4 _Color;
			fixed3 _GlowColor;
			float _FadeLength;	

			sampler2D _FresnelTex;
			float4 _FresnelTex_ST;
			float3 _FresnelColor;
			float _FresnelExponent;

			float GetGlowBorder(float4 vpos)
			{
				float2 screenuv = vpos.xy / _ScreenParams.xy;
				float screenDepth = Linear01Depth(tex2D(_CameraDepthTexture, screenuv));

				float diff = screenDepth - Linear01Depth(vpos.z);

				float intersect = intersect = 1.0 - smoothstep(0, _ProjectionParams.w * _FadeLength, diff);
				/*if (diff > 0){intersect = 1.0 - smoothstep(0, _ProjectionParams.w * _FadeLength, diff);}*/

				return pow(intersect, 4);
			}

			fixed4 frag(v2f i, fixed face : VFACE) : SV_Target
			{	
				//if (face > 0) discard;

				float glowBorder = GetGlowBorder(i.vertex);
			
				float faceFactor = max(sign(face), 0.0);

				fixed4 col = fixed4( lerp( _Color.rgb, _GlowColor, glowBorder), glowBorder + 1.0 * _Color.a * faceFactor );
				
				//if (faceFactor == 0.0) return col;
				
				float3 objectPosition = i.objectPosition; 

				float colorFactor = GetHitColorFactor(objectPosition);								
				float alphaFactor = GetHitAlphaFactor(objectPosition);

				float finalFactor = saturate(colorFactor + alphaFactor);

				col.rgb -= _HitColorIntensity * _Color.rgb * finalFactor;
				col.rgb += _HitColorIntensity * _HitColor.rgb * finalFactor;

				col.a *= 1.0 - saturate(alphaFactor * _HitAlfaIntensity);

				//if (faceFactor == 0.0) return col;

				float fresnel = dot(i.worldNormal, i.viewDir);				
				fresnel = saturate(1 - fresnel);
				fresnel = pow(fresnel, _FresnelExponent * _FresnelTex_ST);
				fixed4 fresnelTexture = tex2D(_FresnelTex, i.uv);

				float3 fresnelColor = fresnel * fresnelTexture * _FresnelColor;				

				col.rgb += fresnelColor * (1.0 - finalFactor);
				
				return col;
			}
			ENDCG
		}
	}
}