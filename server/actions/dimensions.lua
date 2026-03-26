local P = MZ_STAFFPANEL

P.RegisterAction('setMyDimension', {
    resolveTarget = false,
    permission = 'dimension',
}, function(ctx)
    local bucket = tonumber(ctx.payload.dimension or ctx.payload.bucket or 0) or 0
    if bucket < 0 then bucket = 0 end

    SetPlayerRoutingBucket(ctx.src, bucket)

    P.Notify(ctx.src, ('Sua dimensão foi alterada para %d.'):format(bucket), 'success')
    ctx.log('admin_action', 'Alterou a própria dimensão.', { bucket = bucket })
end)

P.RegisterAction('setDimension', {
    requiredTarget = true,
    targetProtected = true,
    permission = 'dimension',
}, function(ctx)
    local bucket = tonumber(ctx.payload.dimension or ctx.payload.bucket or 0) or 0
    if bucket < 0 then bucket = 0 end

    SetPlayerRoutingBucket(ctx.targetSrc, bucket)

    P.Notify(ctx.src, ('Player %d foi para dimensão %d.'):format(ctx.targetSrc, bucket), 'success')
    P.Notify(ctx.targetSrc, ('Você foi movido para dimensão %d.'):format(bucket), 'primary')

    ctx.log('admin_action', 'Alterou dimensão do jogador.', {
        target = ctx.targetSrc,
        bucket = bucket
    })
end)