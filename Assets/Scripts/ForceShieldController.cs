﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ForceShieldController : MonoBehaviour
{
    [SerializeField, Range(0, 1)]
    float _DissolveValue = 0f;

    const int MAX_HITS_COUNT = 10;

    Renderer _renderer;
    MaterialPropertyBlock _mpb;

    int _hitsCount;

    Vector4[] _hitsObjectPosition = new Vector4[MAX_HITS_COUNT];
    float[] _hitsDuration = new float[MAX_HITS_COUNT];
    float[] _hitsTimer = new float[MAX_HITS_COUNT];
    float[] _hitRadius = new float[MAX_HITS_COUNT];

    float[] _hitsIntensity = new float[MAX_HITS_COUNT];

    public void AddHit(Vector3 worldPosition, float duration, float radius)
    {
        int id = GetFreeHitId();
        _hitsObjectPosition[id] = transform.InverseTransformPoint(worldPosition);
        _hitsDuration[id] = duration;
        _hitRadius[id] = radius;

        _hitsTimer[id] = 0;
    }

    int GetFreeHitId()
    {
        if (_hitsCount < MAX_HITS_COUNT)
        {
            _hitsCount++;
            return _hitsCount - 1;
        }
        else
        {
            float minDuration = float.MaxValue;
            int minId = 0;
            for (int i = 0; i < MAX_HITS_COUNT; i++)
            {
                if (_hitsDuration[i] < minDuration)
                {
                    minDuration = _hitsDuration[i];
                    minId = i;
                }
            }
            return minId;
        }
    }

    public void ClearAllHits()
    {
        _hitsCount = 0;
        SendHitsToRenderer();
    }

    void Awake()
    {
        _renderer = GetComponent<Renderer>();
        _mpb = new MaterialPropertyBlock();
    }

    void Update()
    {
        UpdateHitsLifeTime();
        SendHitsToRenderer();
    }
    void UpdateHitsLifeTime()
    {
        for (int i = 0; i < _hitsCount;)
        {
            _hitsTimer[i] += Time.deltaTime;
            if (_hitsTimer[i] > _hitsDuration[i])
            {
                SwapWithLast(i);
            }
            else
            {
                i++;
            }
        }
    }
    void SwapWithLast(int id)
    {
        int idLast = _hitsCount - 1;
        if (id != idLast)
        {
            _hitsObjectPosition[id] = _hitsObjectPosition[idLast];
            _hitsDuration[id] = _hitsDuration[idLast];
            _hitsTimer[id] = _hitsTimer[idLast];
            _hitRadius[id] = _hitRadius[idLast];
        }
        _hitsCount--;
    }

    void SendHitsToRenderer()
    {
        _renderer.GetPropertyBlock(_mpb);

        _mpb.SetFloat("_DissolveValue", _DissolveValue);
        _mpb.SetFloat("_HitsCount", _hitsCount);
        _mpb.SetFloatArray("_HitsRadius", _hitRadius);

        for (int i = 0; i < _hitsCount; i++)
        {
            if (_hitsDuration[i] > 0f)
            {
                _hitsIntensity[i] = 1 - Mathf.Clamp01(_hitsTimer[i] / _hitsDuration[i]);
            }
        }

        _mpb.SetVectorArray("_HitsObjectPosition", _hitsObjectPosition);
        _mpb.SetFloatArray("_HitsIntensity", _hitsIntensity);
        _renderer.SetPropertyBlock(_mpb);
    }
}