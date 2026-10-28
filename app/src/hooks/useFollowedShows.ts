import { useQuery, useMutation, useQueryClient, type QueryClient } from '@tanstack/react-query';
import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import { toast } from '@/hooks/use-toast';
import { validateShowName, validateEpisodeName } from '@/lib/validation';
import {
  markTvEpisodeWatched,
  markTvEpisodesBatch,
  type MarkedTvEpisode,
  removeTvEpisodeWatched,
} from '@/lib/tvEpisodeProgress';

const CONTINUE_WATCHING_VM_QUERY_KEY = ['continue-watching-vm'] as const;

const GUEST_WATCHED_EPISODES_KEY = 'cinetrekker_guest_watched_episodes';

function getGuestWatchedEpisodes(): WatchedEpisode[] {
  if (typeof window === 'undefined' || !window.localStorage) return [];
  try {
    const raw = window.localStorage.getItem(GUEST_WATCHED_EPISODES_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

function saveGuestWatchedEpisodes(episodes: WatchedEpisode[]): void {
  if (typeof window === 'undefined' || !window.localStorage) return;
  try {
    window.localStorage.setItem(GUEST_WATCHED_EPISODES_KEY, JSON.stringify(episodes));
  } catch {
    // ignore
  }
}

function watchedEpisodesQueryKey(userId: string | undefined) {
  return ['watched-episodes', userId || 'guest'] as const;
}

const CW_CARD_ENRICH_QUERY_KEY = ['cw-card-enrich'] as const;
const WATCHED_EPISODES_PAGE_SIZE = 500;

/**
 * Supabase/PostgREST caps an unpaginated response at 1,000 rows. Episode
 * histories can exceed that threshold, so Continue Watching must page through
 * every row before deriving counts, completion, or the next episode.
 */
async function fetchAllWatchedEpisodes(userId: string): Promise<WatchedEpisode[]> {
  const rows: WatchedEpisode[] = [];
  let offset = 0;

  while (true) {
    const { data, error } = await supabase
      .from('watched_episodes')
      .select('*')
      .eq('user_id', userId)
      .order('watched_at', { ascending: false })
      .order('show_id', { ascending: true })
      .order('season_number', { ascending: true })
      .order('episode_number', { ascending: true })
      .range(offset, offset + WATCHED_EPISODES_PAGE_SIZE - 1);

    if (error) throw error;

    const page = (data ?? []) as WatchedEpisode[];
    rows.push(...page);
    if (page.length < WATCHED_EPISODES_PAGE_SIZE) break;
    offset += WATCHED_EPISODES_PAGE_SIZE;
  }

  // A concurrent mark can move a row between pages. Preserve the canonical
  // per-user episode identity even in that narrow race rather than counting it
  // twice and corrupting the derived progress percentage.
  return Array.from(
    new Map(
      rows.map((episode) => [
        `${episode.show_id}-${episode.season_number}-${episode.episode_number}`,
        episode,
      ]),
    ).values(),
  );
}

/** Invalidate derived progress views without touching the episode cache. */
function invalidateDerivedWatchedProgress(
  queryClient: QueryClient,
  userId: string | undefined,
) {
  queryClient.invalidateQueries({ queryKey: ['followed-shows'] });
  queryClient.invalidateQueries({ queryKey: ['watched', userId] });
  queryClient.invalidateQueries({ queryKey: CONTINUE_WATCHING_VM_QUERY_KEY });
  queryClient.invalidateQueries({ queryKey: CW_CARD_ENRICH_QUERY_KEY });
}

/** Full resync after a failed mutation or when the episode cache may be stale. */
function invalidateWatchedProgress(
  queryClient: QueryClient,
  userId: string | undefined,
) {
  queryClient.invalidateQueries({ queryKey: watchedEpisodesQueryKey(userId) });
  invalidateDerivedWatchedProgress(queryClient, userId);
}

async function cancelWatchedProgressQueries(
  queryClient: QueryClient,
  userId: string | undefined,
) {
  await queryClient.cancelQueries({ queryKey: watchedEpisodesQueryKey(userId) });
  await queryClient.cancelQueries({ queryKey: CONTINUE_WATCHING_VM_QUERY_KEY });
  await queryClient.cancelQueries({ queryKey: CW_CARD_ENRICH_QUERY_KEY });
}

function buildOptimisticEpisode(
  userId: string,
  input: {
    showId: number;
    seasonNumber: number;
    episodeNumber: number;
    episodeName?: string;
    airDate?: string;
  },
): WatchedEpisode {
  return {
    id: `optimistic-${input.showId}-${input.seasonNumber}-${input.episodeNumber}`,
    user_id: userId,
    show_id: input.showId,
    season_number: input.seasonNumber,
    episode_number: input.episodeNumber,
    episode_name: input.episodeName ?? null,
    air_date: input.airDate ?? null,
    watched_at: new Date().toISOString(),
  };
}

/**
 * Replace an optimistic row with the row returned by the transaction.
 *
 * The RPC response is the mutation's commit-time source of truth. Keeping it
 * in the cache avoids an immediately-following read racing an optimistic
 * update and restoring an old episode list.
 */
function reconcilePersistedEpisode(
  queryClient: QueryClient,
  userId: string,
  episode: MarkedTvEpisode,
) {
  const queryKey = watchedEpisodesQueryKey(userId);
  queryClient.setQueryData<WatchedEpisode[]>(queryKey, (old = []) => [
    episode,
    ...old.filter(
      (current) =>
        !(
          current.show_id === episode.show_id &&
          current.season_number === episode.season_number &&
          current.episode_number === episode.episode_number
        ),
    ),
  ]);
}

export interface FollowedShow {
  id: string;
  user_id: string;
  show_id: number;
  show_name: string;
  poster_path: string | null;
  last_watched_season: number;
  last_watched_episode: number;
  followed_at: string;
}

export interface WatchedEpisode {
  id: string;
  user_id: string;
  show_id: number;
  season_number: number;
  episode_number: number;
  episode_name: string | null;
  air_date: string | null;
  watched_at: string;
}

export function useFollowedShows() {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  const { data: followedShows = [], isLoading } = useQuery({
    queryKey: ['followed-shows', user?.id],
    queryFn: async () => {
      if (!user) return [];
      const { data, error } = await supabase
        .from('followed_shows')
        .select('*')
        .eq('user_id', user.id)
        .order('followed_at', { ascending: false });
      
      if (error) throw error;
      return data as FollowedShow[];
    },
    enabled: !!user,
  });

  const followShowMutation = useMutation({
    mutationFn: async ({ showId, showName, posterPath }: { showId: number; showName: string; posterPath: string | null }) => {
      if (!user) throw new Error('Not authenticated');
      
      // Validate show name
      const validatedShowName = validateShowName(showName);
      
      const { error } = await supabase
        .from('followed_shows')
        .upsert({
          user_id: user.id,
          show_id: showId,
          show_name: validatedShowName,
          poster_path: posterPath,
        }, { onConflict: 'user_id,show_id' });
      
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['followed-shows'] });
      toast({ title: 'Show followed!' });
    },
    onError: (error: Error) => {
      toast({ title: 'Error', description: error.message, variant: 'destructive' });
    },
  });

  const unfollowShowMutation = useMutation({
    mutationFn: async (showId: number) => {
      if (!user) throw new Error('Not authenticated');
      
      const { error } = await supabase
        .from('followed_shows')
        .delete()
        .eq('user_id', user.id)
        .eq('show_id', showId);
      
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['followed-shows'] });
      toast({ title: 'Show unfollowed' });
    },
    onError: (error: Error) => {
      toast({ title: 'Error', description: error.message, variant: 'destructive' });
    },
  });

  const isFollowing = (showId: number) => {
    return followedShows.some(show => show.show_id === showId);
  };

  return {
    followedShows,
    isLoading,
    followShow: followShowMutation.mutate,
    unfollowShow: unfollowShowMutation.mutate,
    isFollowing,
  };
}

export function useWatchedEpisodes(showId?: number) {
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  const {
    data: allWatchedEpisodes = [],
    isLoading,
    refetch,
  } = useQuery({
    // Keep one canonical cache for a user's episode history. A show-scoped
    // cache and an all-shows cache can resolve at different times and leave
    // the details page and Continue Watching with contradictory progress.
    queryKey: ['watched-episodes', user?.id || 'guest'],
    queryFn: async () => {
      if (!user) return getGuestWatchedEpisodes();
      
      return fetchAllWatchedEpisodes(user.id);
    },
    enabled: true,
    staleTime: 30_000,
  });

  const watchedEpisodes = useMemo(
    () =>
      showId == null
        ? allWatchedEpisodes
        : allWatchedEpisodes.filter((episode) => episode.show_id === showId),
    [allWatchedEpisodes, showId],
  );

  // ── Mark single episode ────────────────────────────────────────────────────
  const markEpisodeWatchedMutation = useMutation({
    mutationFn: async ({
      showId: sid,
      seasonNumber,
      episodeNumber,
      episodeName,
      airDate,
      showName,
      posterPath,
    }: {
      showId: number;
      seasonNumber: number;
      episodeNumber: number;
      episodeName?: string;
      airDate?: string;
      showName?: string;
      posterPath?: string | null;
    }) => {
      const validatedEpisodeName = validateEpisodeName(episodeName);
      const validatedShowName = showName ? validateShowName(showName) : undefined;

      if (!user) {
        const optimistic = buildOptimisticEpisode('guest', {
          showId: sid,
          seasonNumber,
          episodeNumber,
          episodeName: validatedEpisodeName || undefined,
          airDate: airDate || undefined,
        });
        const list = getGuestWatchedEpisodes().filter(
          (e) => !(e.show_id === sid && e.season_number === seasonNumber && e.episode_number === episodeNumber)
        );
        list.unshift(optimistic);
        saveGuestWatchedEpisodes(list);
        return optimistic;
      }

      return markTvEpisodeWatched({
        showId: sid,
        seasonNumber,
        episodeNumber,
        episodeName: validatedEpisodeName || null,
        airDate: airDate || null,
        showName: validatedShowName ?? null,
        posterPath: posterPath ?? null,
      });
    },
    onMutate: async (variables) => {
      const activeId = user?.id || 'guest';
      const queryKey = watchedEpisodesQueryKey(activeId);
      await cancelWatchedProgressQueries(queryClient, user.id);

      const previous = queryClient.getQueryData<WatchedEpisode[]>(queryKey);
      const optimistic = buildOptimisticEpisode(activeId, {
        showId: variables.showId,
        seasonNumber: variables.seasonNumber,
        episodeNumber: variables.episodeNumber,
        episodeName: variables.episodeName,
        airDate: variables.airDate,
      });

      queryClient.setQueryData<WatchedEpisode[]>(queryKey, (old = []) => [
        optimistic,
        ...old.filter(
          (episode) =>
            !(
              episode.show_id === variables.showId &&
              episode.season_number === variables.seasonNumber &&
              episode.episode_number === variables.episodeNumber
            ),
        ),
      ]);

      return { previous };
    },
    onSuccess: (persistedEpisode) => {
      toast({ title: t('progress.episodeMarkedWatched', 'Episode marked as watched') });
      const activeId = user?.id || 'guest';
      // Replace optimistic row with the DB-committed row; no extra refetch needed.
      reconcilePersistedEpisode(queryClient, activeId, persistedEpisode);
      invalidateDerivedWatchedProgress(queryClient, activeId);
    },
    onError: (error: Error, _variables, context) => {
      if (context?.previous) {
        queryClient.setQueryData(watchedEpisodesQueryKey(user?.id), context.previous);
      }
      toast({
        title: t('common.error', 'An error occurred'),
        description: error.message,
        variant: 'destructive',
      });
      invalidateWatchedProgress(queryClient, activeId);
    },
  });

  // ── Remove single episode ──────────────────────────────────────────────────
  const removeEpisodeWatchedMutation = useMutation({
    mutationFn: async ({ showId: sid, seasonNumber, episodeNumber }: { showId: number; seasonNumber: number; episodeNumber: number }) => {
      if (!user) {
        const list = getGuestWatchedEpisodes().filter(
          (e) => !(e.show_id === sid && e.season_number === seasonNumber && e.episode_number === episodeNumber)
        );
        saveGuestWatchedEpisodes(list);
        return;
      }
      await removeTvEpisodeWatched(sid, seasonNumber, episodeNumber);
    },
    onMutate: async (variables) => {
      const activeId = user?.id || 'guest';
      const queryKey = watchedEpisodesQueryKey(activeId);
      await cancelWatchedProgressQueries(queryClient, user.id);

      const previous = queryClient.getQueryData<WatchedEpisode[]>(queryKey);
      // Remove optimistically — no refetch needed on success.
      queryClient.setQueryData<WatchedEpisode[]>(queryKey, (old = []) =>
        old.filter(
          (episode) =>
            !(
              episode.show_id === variables.showId &&
              episode.season_number === variables.seasonNumber &&
              episode.episode_number === variables.episodeNumber
            ),
        ),
      );

      return { previous };
    },
    onSuccess: () => {
      toast({ title: t('progress.episodeRemoved', 'Episode removed from progress') });
      const activeId = user?.id || 'guest';
      // Optimistic removal already applied; only invalidate derived views.
      invalidateDerivedWatchedProgress(queryClient, activeId);
    },
    onError: (error: Error, _variables, context) => {
      if (context?.previous) {
        queryClient.setQueryData(watchedEpisodesQueryKey(user?.id), context.previous);
      }
      toast({
        title: t('common.error', 'An error occurred'),
        description: error.message,
        variant: 'destructive',
      });
      invalidateWatchedProgress(queryClient, activeId);
    },
  });

  // ── Mark whole season ──────────────────────────────────────────────────────
  const markSeasonWatchedMutation = useMutation({
    mutationFn: async ({
      showId: sid,
      seasonNumber,
      episodes,
      showName,
      posterPath,
    }: {
      showId: number;
      seasonNumber: number;
      episodes: Array<{ episode_number: number; name?: string; air_date?: string }>;
      showName?: string;
      posterPath?: string | null;
    }) => {
      const validatedShowName = showName ? validateShowName(showName) : undefined;
      const lastEpisode = episodes[episodes.length - 1];

      if (!user) {
        const existing = getGuestWatchedEpisodes().filter(
          (e) => !(e.show_id === sid && e.season_number === seasonNumber)
        );
        const newEps = episodes.map((ep) =>
          buildOptimisticEpisode('guest', {
            showId: sid,
            seasonNumber,
            episodeNumber: ep.episode_number,
            episodeName: ep.name,
            airDate: ep.air_date,
          })
        );
        saveGuestWatchedEpisodes([...newEps, ...existing]);
        return;
      }

      await markTvEpisodesBatch({
        showId: sid,
        episodes: episodes.map((ep) => ({
          season_number: seasonNumber,
          episode_number: ep.episode_number,
          episode_name: validateEpisodeName(ep.name) || null,
          air_date: ep.air_date || null,
        })),
        showName: validatedShowName ?? null,
        posterPath: posterPath ?? null,
        lastWatchedSeason: seasonNumber,
        lastWatchedEpisode: lastEpisode.episode_number,
        watchedStatus: 'watching',
      });
    },
    onMutate: async (variables) => {
      const activeId = user?.id || 'guest';
      const queryKey = watchedEpisodesQueryKey(activeId);
      await cancelWatchedProgressQueries(queryClient, user.id);

      const previous = queryClient.getQueryData<WatchedEpisode[]>(queryKey);
      const optimistic = variables.episodes.map((episode) =>
        buildOptimisticEpisode(activeId, {
          showId: variables.showId,
          seasonNumber: variables.seasonNumber,
          episodeNumber: episode.episode_number,
          episodeName: episode.name,
          airDate: episode.air_date,
        }),
      );

      queryClient.setQueryData<WatchedEpisode[]>(queryKey, (old = []) => {
        // Remove existing entries for this show+season, then prepend optimistic.
        const remaining = old.filter(
          (episode) =>
            !(
              episode.show_id === variables.showId &&
              episode.season_number === variables.seasonNumber
            ),
        );
        return [...optimistic, ...remaining];
      });

      return { previous };
    },
    onSuccess: () => {
      toast({ title: t('progress.seasonMarkedWatched', 'Season marked as watched') });
      const activeId = user?.id || 'guest';
      // Optimistic update already applied; only invalidate derived views.
      invalidateDerivedWatchedProgress(queryClient, activeId);
    },
    onError: (error: Error, _variables, context) => {
      if (context?.previous) {
        queryClient.setQueryData(watchedEpisodesQueryKey(user?.id), context.previous);
      }
      toast({
        title: t('common.error', 'An error occurred'),
        description: error.message,
        variant: 'destructive',
      });
      invalidateWatchedProgress(queryClient, activeId);
    },
  });

  // ── Mark all seasons ───────────────────────────────────────────────────────
  const markAllSeasonsWatchedMutation = useMutation({
    mutationFn: async ({
      showId: sid,
      allEpisodes,
      showName,
      posterPath,
    }: {
      showId: number;
      allEpisodes: Array<{ season_number: number; episode_number: number; name?: string; air_date?: string }>;
      showName?: string;
      posterPath?: string | null;
    }) => {
      const validatedShowName = showName ? validateShowName(showName) : undefined;

      if (!user) {
        const existing = getGuestWatchedEpisodes().filter((e) => e.show_id !== sid);
        const newEps = allEpisodes.map((ep) =>
          buildOptimisticEpisode('guest', {
            showId: sid,
            seasonNumber: ep.season_number,
            episodeNumber: ep.episode_number,
            episodeName: ep.name,
            airDate: ep.air_date,
          })
        );
        saveGuestWatchedEpisodes([...newEps, ...existing]);
        return;
      }

      const lastEpisode = allEpisodes.reduce((latest, current) => {
        if (current.season_number > latest.season_number) return current;
        if (current.season_number === latest.season_number && current.episode_number > latest.episode_number) return current;
        return latest;
      });

      await markTvEpisodesBatch({
        showId: sid,
        episodes: allEpisodes.map((ep) => ({
          season_number: ep.season_number,
          episode_number: ep.episode_number,
          episode_name: validateEpisodeName(ep.name) || null,
          air_date: ep.air_date || null,
        })),
        showName: validatedShowName ?? null,
        posterPath: posterPath ?? null,
        lastWatchedSeason: lastEpisode.season_number,
        lastWatchedEpisode: lastEpisode.episode_number,
        watchedStatus: 'completed',
      });
    },
    onMutate: async (variables) => {
      const activeId = user?.id || 'guest';
      const queryKey = watchedEpisodesQueryKey(activeId);
      await cancelWatchedProgressQueries(queryClient, user.id);

      const previous = queryClient.getQueryData<WatchedEpisode[]>(queryKey);
      const optimistic = variables.allEpisodes.map((episode) =>
        buildOptimisticEpisode(activeId, {
          showId: variables.showId,
          seasonNumber: episode.season_number,
          episodeNumber: episode.episode_number,
          episodeName: episode.name,
          airDate: episode.air_date,
        }),
      );

      queryClient.setQueryData<WatchedEpisode[]>(queryKey, (old = []) => {
        // Remove all existing entries for this show, then prepend all optimistic.
        const remaining = old.filter((episode) => episode.show_id !== variables.showId);
        return [...optimistic, ...remaining];
      });

      return { previous };
    },
    onSuccess: () => {
      toast({ title: t('progress.allSeasonsMarkedWatched', 'All seasons marked as watched') });
      const activeId = user?.id || 'guest';
      // Optimistic update already applied; only invalidate derived views.
      invalidateDerivedWatchedProgress(queryClient, activeId);
    },
    onError: (error: Error, _variables, context) => {
      if (context?.previous) {
        queryClient.setQueryData(watchedEpisodesQueryKey(user?.id), context.previous);
      }
      toast({
        title: t('common.error', 'An error occurred'),
        description: error.message,
        variant: 'destructive',
      });
      invalidateWatchedProgress(queryClient, activeId);
    },
  });

  const isEpisodeWatched = (sid: number, seasonNumber: number, episodeNumber: number) => {
    return watchedEpisodes.some(
      ep => ep.show_id === sid && ep.season_number === seasonNumber && ep.episode_number === episodeNumber
    );
  };

  return {
    watchedEpisodes,
    isLoading,
    refetch,
    markEpisodeWatched: markEpisodeWatchedMutation.mutate,
    isMarkingEpisodeWatched: markEpisodeWatchedMutation.isPending,
    markingEpisodeTarget: markEpisodeWatchedMutation.isPending
      ? markEpisodeWatchedMutation.variables ?? null
      : null,
    removeEpisodeWatched: removeEpisodeWatchedMutation.mutate,
    markSeasonWatched: markSeasonWatchedMutation.mutate,
    markAllSeasonsWatched: markAllSeasonsWatchedMutation.mutate,
    markAllSeasonsWatchedAsync: markAllSeasonsWatchedMutation.mutateAsync,
    isEpisodeWatched,
  };
}
