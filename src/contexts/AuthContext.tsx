import React, { createContext, useContext, useEffect, useState } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import type { Database } from '../types/supabase';

type UserProfile = Database['public']['Tables']['user_profiles']['Row'];

interface AuthContextType {
  user: User | null;
  userProfile: UserProfile | null;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  loading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [userProfile, setUserProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [session, setSession] = useState<Session | null>(null);

  useEffect(() => {
    let mounted = true;

    supabase.auth.getSession().then(({ data: { session } }) => {
      if (mounted) {
        setSession(session);
        setUser(session?.user ?? null);
      }
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      if (mounted) {
        setSession(session);
        setUser(session?.user ?? null);
      }
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    let mounted = true;

    async function fetchProfile() {
      if (!user) {
        if (mounted) {
          setUserProfile(null);
          setLoading(false);
        }
        return;
      }

      try {
        const { data, error } = await supabase
          .from('user_profiles')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

        if (mounted) {
          if (error) {
            console.error('Error fetching user profile:', error);
            setUserProfile(null);
          } else {
            setUserProfile(data);
          }
          setLoading(false);
        }
      } catch (error) {
        console.error('Error in fetchProfile:', error);
        if (mounted) {
          setUserProfile(null);
          setLoading(false);
        }
      }
    }

    setLoading(true);
    fetchProfile();

    return () => {
      mounted = false;
    };
  }, [user]);

  const signIn = async (email: string, password: string) => {
    try {
      setLoading(true);
      const { error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      });

      if (error) throw error;
    } catch (error) {
      console.error('Error signing in:', error);
      throw error;
    } finally {
      setLoading(false);
    }
  };

  const clearStorageItems = () => {
    // Clear Supabase items from localStorage
    const supabaseKeys = Object.keys(localStorage).filter(key => 
      key.startsWith('sb-') || 
      key.startsWith('supabase.auth.') ||
      key.includes('supabase')
    );
    
    supabaseKeys.forEach(key => localStorage.removeItem(key));

    // Clear session storage
    sessionStorage.clear();
  };

  const signOut = async () => {
    try {
      setLoading(true);

      // First clear all storage items
      clearStorageItems();

      // Clear the Supabase session
      await supabase.auth.signOut({ scope: 'local' });

      // Clear local state
      setUser(null);
      setUserProfile(null);
      setSession(null);

      // Double-check storage is cleared
      clearStorageItems();

      // Force a page reload to ensure clean state
      window.location.href = '/login';
    } catch (error) {
      console.error('Error in signOut:', error);
      // Even if there's an error, ensure we clean up
      clearStorageItems();
      setUser(null);
      setUserProfile(null);
      setSession(null);
      window.location.href = '/login';
    } finally {
      setLoading(false);
    }
  };

  const value = {
    user,
    userProfile,
    signIn,
    signOut,
    loading,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}